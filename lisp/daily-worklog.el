;;; daily-worklog.el --- Daily buffer and project time summaries  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Aleksandr Savchenko

;; Author: Aleksandr Savchenko <aleksandr.savchenko.eu@gmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1"))
;; Keywords: convenience

;;; Commentary:

;; `daily-worklog-mode' maintains an approximate, privacy-preserving summary
;; of focused time spent in Emacs buffers and projects.  Buffer changes only
;; update in-memory totals.  Compact daily JSON files are written periodically,
;; at local midnight, when the mode is disabled, before Emacs exits, or when
;; `daily-worklog-save' is called explicitly.
;;
;; Projectile is used for project detection when it is available.  Otherwise
;; the package falls back to the built-in project.el library.  No external
;; package is required, and no buffer contents, commands, keystrokes, terminal
;; contents, selected text, or other user input are recorded.
;;
;; A minimal configuration is:
;;
;;   (use-package daily-worklog
;;     :ensure nil
;;     :load-path "lisp"
;;     :demand t
;;     :config
;;     (daily-worklog-mode 1))

;;; Code:

(require 'cl-lib)
(require 'json)
(require 'project)
(require 'seq)
(require 'subr-x)

(defgroup daily-worklog nil
  "Approximate daily buffer and project time summaries."
  :group 'convenience
  :prefix "daily-worklog-")

(defcustom daily-worklog-directory
  (expand-file-name "daily-worklog/" user-emacs-directory)
  "Directory in which daily worklog JSON files are stored."
  :type 'directory
  :group 'daily-worklog)

(defcustom daily-worklog-save-interval 900
  "Number of seconds between automatic worklog saves."
  :type '(integer :tag "Seconds")
  :group 'daily-worklog)

(defcustom daily-worklog-ignored-buffer-regexp
  "\\`\\(?:\\*Messages\\*\\|\\*Completions\\*\\)\\'"
  "Regexp matching buffer names that should not be tracked.

Minibuffers and buffers whose names start with a space are always ignored."
  :type 'regexp
  :group 'daily-worklog)

(defcustom daily-worklog-track-remote-buffers nil
  "When non-nil, include remote and TRAMP buffers in the worklog."
  :type 'boolean
  :group 'daily-worklog)

(cl-defstruct (daily-worklog--entry
               (:constructor daily-worklog--make-entry))
  buffer
  name
  major-mode
  project-name
  project-root)

(cl-defstruct (daily-worklog--project
               (:constructor daily-worklog--make-project))
  name
  root
  buffers)

(defconst daily-worklog--uncached (make-symbol "daily-worklog--uncached")
  "Sentinel used for unresolved buffer-local project information.")

(defvar-local daily-worklog--project-cache daily-worklog--uncached
  "Cached project plist for the current buffer.")

(defvar daily-worklog--dates (make-hash-table :test #'equal)
  "Map local date strings to project tables.")

(defvar daily-worklog--loaded-dates (make-hash-table :test #'equal)
  "Set of dates whose existing summaries have been loaded.")

(defvar daily-worklog--dirty-dates (make-hash-table :test #'equal)
  "Set of dates changed since their last successful save.")

(defvar daily-worklog--selected-buffer nil
  "Last effective buffer observed in the selected window.")

(defvar daily-worklog--active-entry nil
  "Metadata for the buffer whose current interval is being timed.")

(defvar daily-worklog--interval-start nil
  "Time at which the current active interval started.")

(defvar daily-worklog--focused-p nil
  "Non-nil while Emacs is considered focused for tracking purposes.")

(defvar daily-worklog--save-timer nil
  "Repeating timer used for periodic worklog saves.")

(defvar daily-worklog--midnight-timer nil
  "One-shot timer used to save at the next local midnight.")

(defvar daily-worklog--running-p nil
  "Non-nil while the mode's hooks and timers are installed.")

(defun daily-worklog--date-string (time)
  "Return the local calendar date containing TIME."
  (format-time-string "%Y-%m-%d" time))

(defun daily-worklog--timestamp-string (time)
  "Return TIME as a local ISO-8601 timestamp."
  (format-time-string "%Y-%m-%dT%H:%M:%S%:z" time))

(defun daily-worklog--next-midnight (time)
  "Return the local midnight immediately following TIME."
  (let ((decoded (decode-time time)))
    (encode-time 0 0 0
                 (1+ (nth 3 decoded))
                 (nth 4 decoded)
                 (nth 5 decoded))))

(defun daily-worklog--normalize-root (root)
  "Return normalized project ROOT without a trailing slash."
  (when root
    (directory-file-name (expand-file-name root))))

(defun daily-worklog--default-project-name (root)
  "Return a human-readable project name derived from ROOT."
  (file-name-nondirectory (directory-file-name root)))

(defun daily-worklog--projectile-info (directory)
  "Return Projectile project information for DIRECTORY, or nil."
  (when (and directory (fboundp 'projectile-project-root))
    (condition-case nil
        (let ((root (projectile-project-root directory)))
          (when root
            (setq root (daily-worklog--normalize-root root))
            (list :name (if (fboundp 'projectile-project-name)
                            (projectile-project-name root)
                          (daily-worklog--default-project-name root))
                  :root root)))
      (error nil))))

(defun daily-worklog--builtin-project-info (directory)
  "Return built-in project information for DIRECTORY, or nil."
  (when directory
    (condition-case nil
        (when-let* ((project (project-current nil directory))
                    (root (daily-worklog--normalize-root
                           (project-root project))))
          (list :name (if (fboundp 'project-name)
                          (project-name project)
                        (daily-worklog--default-project-name root))
                :root root))
      (error nil))))

(defun daily-worklog--resolve-project (buffer)
  "Return cached project information for BUFFER."
  (with-current-buffer buffer
    (if (not (eq daily-worklog--project-cache daily-worklog--uncached))
        daily-worklog--project-cache
      (let* ((directory (or (and buffer-file-name
                                 (file-name-directory buffer-file-name))
                            default-directory))
             (project (or (daily-worklog--projectile-info directory)
                          (daily-worklog--builtin-project-info directory)
                          (list :name "Unassigned" :root nil))))
        (setq daily-worklog--project-cache project)))))

(defun daily-worklog--remote-buffer-p (buffer)
  "Return non-nil when BUFFER is associated with a remote location."
  (with-current-buffer buffer
    (or (and buffer-file-name (file-remote-p buffer-file-name))
        (and default-directory (file-remote-p default-directory)))))

(defun daily-worklog--trackable-buffer-p (buffer)
  "Return non-nil when BUFFER should be included in the worklog."
  (and (buffer-live-p buffer)
       (not (minibufferp buffer))
       (let ((name (buffer-name buffer)))
         (and name
              (not (string-prefix-p " " name))
              (not (and daily-worklog-ignored-buffer-regexp
                        (string-match-p daily-worklog-ignored-buffer-regexp
                                        name)))))
       (or daily-worklog-track-remote-buffers
           (not (daily-worklog--remote-buffer-p buffer)))))

(defun daily-worklog--entry-for-buffer (buffer)
  "Build tracking metadata for BUFFER, or nil when it is ignored."
  (when (daily-worklog--trackable-buffer-p buffer)
    (let ((project (daily-worklog--resolve-project buffer)))
      (with-current-buffer buffer
        (daily-worklog--make-entry
         :buffer buffer
         :name (buffer-name buffer)
         :major-mode (symbol-name major-mode)
         :project-name (plist-get project :name)
         :project-root (plist-get project :root))))))

(defun daily-worklog--date-table (date)
  "Return the project table for DATE, creating it in memory if needed."
  (or (gethash date daily-worklog--dates)
      (let ((table (make-hash-table :test #'equal)))
        (puthash date table daily-worklog--dates)
        table)))

(defun daily-worklog--project-record (table entry)
  "Return the project record in TABLE corresponding to ENTRY."
  (let* ((root (daily-worklog--entry-project-root entry))
         (record (gethash root table)))
    (or record
        (let ((new (daily-worklog--make-project
                    :name (daily-worklog--entry-project-name entry)
                    :root root
                    :buffers (make-hash-table :test #'equal))))
          (puthash root new table)
          new))))

(defun daily-worklog--add-seconds (date entry seconds)
  "Add SECONDS to ENTRY on DATE entirely in memory."
  (when (> seconds 0)
    (let* ((table (daily-worklog--date-table date))
           (project (daily-worklog--project-record table entry))
           (buffers (daily-worklog--project-buffers project))
           (key (cons (daily-worklog--entry-name entry)
                      (daily-worklog--entry-major-mode entry))))
      (puthash key (+ seconds (gethash key buffers 0.0)) buffers)
      (puthash date t daily-worklog--dirty-dates))))

(defun daily-worklog--accumulate (entry start end)
  "Accumulate ENTRY from START to END, splitting at local midnights."
  (when (time-less-p start end)
    (let ((cursor start))
      (while (time-less-p cursor end)
        (let* ((midnight (daily-worklog--next-midnight cursor))
               (segment-end (if (time-less-p midnight end)
                                midnight
                              end))
               (seconds (max 0.0
                             (float-time
                              (time-subtract segment-end cursor)))))
          (daily-worklog--add-seconds
           (daily-worklog--date-string cursor) entry seconds)
          (setq cursor segment-end))))))

(defun daily-worklog--checkpoint (now &optional resume)
  "Commit the current interval at NOW and optionally RESUME it."
  (let ((entry daily-worklog--active-entry)
        (start daily-worklog--interval-start))
    (when (and entry start)
      (daily-worklog--accumulate entry start now))
    (if (and resume entry daily-worklog--focused-p)
        (setq daily-worklog--interval-start now)
      (setq daily-worklog--active-entry nil
            daily-worklog--interval-start nil))))

(defun daily-worklog--select-buffer (buffer now &optional force)
  "Begin tracking BUFFER at NOW after committing the previous buffer.

When FORCE is non-nil, restart even if BUFFER was already selected."
  (when (and daily-worklog--running-p daily-worklog--focused-p
             (buffer-live-p buffer)
             (or force (not (eq buffer daily-worklog--selected-buffer))))
    (daily-worklog--checkpoint now nil)
    (setq daily-worklog--selected-buffer buffer
          daily-worklog--active-entry
          (daily-worklog--entry-for-buffer buffer)
          daily-worklog--interval-start
          (and daily-worklog--active-entry now))))

(defun daily-worklog--window-change (frame)
  "Notice the effective selected buffer after a change on FRAME."
  (when (and daily-worklog--running-p
             daily-worklog--focused-p
             (frame-live-p frame)
             (eq frame (selected-frame)))
    (let ((window (frame-selected-window frame)))
      (when (and (window-live-p window)
                 (eq window (selected-window)))
        (daily-worklog--select-buffer
         (window-buffer window) (current-time))))))

(defun daily-worklog--focus-out ()
  "Stop timing when all Emacs frames lose focus."
  (when (and daily-worklog--running-p daily-worklog--focused-p)
    (daily-worklog--checkpoint (current-time) nil)
    (setq daily-worklog--focused-p nil)))

(defun daily-worklog--focus-in ()
  "Resume timing the selected buffer when Emacs regains focus."
  (when (and daily-worklog--running-p (not daily-worklog--focused-p))
    (setq daily-worklog--focused-p t)
    (daily-worklog--select-buffer (window-buffer (selected-window))
                                  (current-time) t)))

(defun daily-worklog--date-file (date)
  "Return the worklog file name for DATE."
  (expand-file-name (concat date ".json") daily-worklog-directory))

(defun daily-worklog--valid-date-p (date)
  "Return non-nil when DATE is a valid YYYY-MM-DD local date."
  (save-match-data
    (and (stringp date)
         (string-match
          "\\`\\([0-9]\\{4\\}\\)-\\([0-9]\\{2\\}\\)-\\([0-9]\\{2\\}\\)\\'"
          date)
         (condition-case nil
             (let ((time (encode-time
                          0 0 0
                          (string-to-number (match-string 3 date))
                          (string-to-number (match-string 2 date))
                          (string-to-number (match-string 1 date)))))
               (string= date (daily-worklog--date-string time)))
           (error nil)))))

(defun daily-worklog--validate-summary (summary expected-date)
  "Validate SUMMARY for EXPECTED-DATE and return SUMMARY.

Signal an error when the JSON schema is unsuitable for recovery."
  (unless (and (listp summary)
               (equal (alist-get 'date summary) expected-date)
               (stringp (alist-get 'updatedAt summary))
               (numberp (alist-get 'totalSeconds summary))
               (listp (alist-get 'projects summary)))
    (error "Invalid daily worklog summary for %s" expected-date))
  (dolist (project (alist-get 'projects summary))
    (unless (and (listp project)
                 (stringp (alist-get 'name project))
                 (let ((root (alist-get 'root project)))
                   (or (null root) (stringp root)))
                 (numberp (alist-get 'totalSeconds project))
                 (listp (alist-get 'buffers project)))
      (error "Invalid project in daily worklog for %s" expected-date))
    (dolist (buffer (alist-get 'buffers project))
      (unless (and (listp buffer)
                   (stringp (alist-get 'name buffer))
                   (stringp (alist-get 'majorMode buffer))
                   (numberp (alist-get 'totalSeconds buffer))
                   (>= (alist-get 'totalSeconds buffer) 0))
        (error "Invalid buffer in daily worklog for %s" expected-date))))
  summary)

(defun daily-worklog--read-summary (date)
  "Read and validate DATE's summary, or return nil if it does not exist."
  (let ((file (daily-worklog--date-file date)))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (daily-worklog--validate-summary
         (json-parse-buffer :object-type 'alist
                            :array-type 'list
                            :null-object nil
                            :false-object nil)
         date)))))

(defun daily-worklog--merge-summary (summary)
  "Merge a validated persisted SUMMARY into in-memory totals."
  (let* ((date (alist-get 'date summary))
         (table (daily-worklog--date-table date)))
    (dolist (project-data (alist-get 'projects summary))
      (let* ((root (daily-worklog--normalize-root
                    (alist-get 'root project-data)))
             (project (or (gethash root table)
                          (let ((new (daily-worklog--make-project
                                      :name (alist-get 'name project-data)
                                      :root root
                                      :buffers (make-hash-table
                                                :test #'equal))))
                            (puthash root new table)
                            new)))
             (buffers (daily-worklog--project-buffers project)))
        (dolist (buffer-data (alist-get 'buffers project-data))
          (let ((key (cons (alist-get 'name buffer-data)
                           (alist-get 'majorMode buffer-data))))
            (puthash key
                     (+ (gethash key buffers 0.0)
                        (alist-get 'totalSeconds buffer-data))
                     buffers)))))))

(defun daily-worklog--ensure-date-loaded (date)
  "Load DATE's existing summary once, merging with unsaved memory."
  (unless (gethash date daily-worklog--loaded-dates)
    (condition-case error-data
        (when-let* ((summary (daily-worklog--read-summary date)))
          (daily-worklog--merge-summary summary))
      (error
       (display-warning
        'daily-worklog
        (format "Could not load %s: %s"
                (daily-worklog--date-file date)
                (error-message-string error-data))
        :warning)))
    (puthash date t daily-worklog--loaded-dates)))

(defun daily-worklog--buffer-summary (key seconds)
  "Return a JSON-ready summary for buffer KEY and SECONDS."
  `((name . ,(car key))
    (majorMode . ,(cdr key))
    (totalSeconds . ,(max 0 (round seconds)))))

(defun daily-worklog--summary-for-date (date now)
  "Return an alist summary for DATE using update time NOW."
  (let ((table (gethash date daily-worklog--dates))
        projects)
    (when table
      (maphash
       (lambda (_root project)
         (let (buffers)
           (maphash
            (lambda (key seconds)
              (push (daily-worklog--buffer-summary key seconds) buffers))
            (daily-worklog--project-buffers project))
           (setq buffers
                 (sort buffers
                       (lambda (left right)
                         (let ((left-seconds (alist-get 'totalSeconds left))
                               (right-seconds (alist-get 'totalSeconds right)))
                           (if (/= left-seconds right-seconds)
                               (> left-seconds right-seconds)
                             (let ((left-name (alist-get 'name left))
                                   (right-name (alist-get 'name right)))
                               (if (string= left-name right-name)
                                   (string< (alist-get 'majorMode left)
                                            (alist-get 'majorMode right))
                                 (string< left-name right-name))))))))
           (let ((total (cl-loop for buffer in buffers
                                 sum (alist-get 'totalSeconds buffer))))
             (push `((name . ,(daily-worklog--project-name project))
                     (root . ,(daily-worklog--project-root project))
                     (totalSeconds . ,total)
                     (buffers . ,(vconcat buffers)))
                   projects))))
       table))
    (setq projects
          (sort projects
                (lambda (left right)
                  (let ((left-seconds (alist-get 'totalSeconds left))
                        (right-seconds (alist-get 'totalSeconds right)))
                    (if (/= left-seconds right-seconds)
                        (> left-seconds right-seconds)
                      (let ((left-name (alist-get 'name left))
                            (right-name (alist-get 'name right)))
                        (if (string= left-name right-name)
                            (string< (or (alist-get 'root left) "")
                                     (or (alist-get 'root right) ""))
                          (string< left-name right-name))))))))
    (let ((total (cl-loop for project in projects
                          sum (alist-get 'totalSeconds project))))
      `((date . ,date)
        (updatedAt . ,(daily-worklog--timestamp-string now))
        (totalSeconds . ,total)
        (projects . ,(vconcat projects))))))

(defun daily-worklog--write-summary (summary)
  "Atomically write SUMMARY to its daily JSON file."
  (make-directory daily-worklog-directory t)
  (let* ((date (alist-get 'date summary))
         (target (daily-worklog--date-file date))
         (prefix (expand-file-name ".daily-worklog-"
                                   daily-worklog-directory))
         (temporary (make-temp-file prefix nil ".json")))
    (unwind-protect
        (progn
          (let ((coding-system-for-write 'utf-8-unix))
            (write-region
             (concat (json-serialize summary
                                     :null-object nil
                                     :false-object :json-false)
                     "\n")
             nil temporary nil 'silent))
          (rename-file temporary target t)
          (setq temporary nil))
      (when (and temporary (file-exists-p temporary))
        (delete-file temporary)))))

(defun daily-worklog--save-dates (dates now)
  "Save DATES with a shared update timestamp NOW."
  (dolist (date (delete-dups dates))
    (daily-worklog--ensure-date-loaded date)
    (daily-worklog--write-summary
     (daily-worklog--summary-for-date date now))
    (remhash date daily-worklog--dirty-dates)))

(defun daily-worklog--dirty-date-list ()
  "Return a list of dates with unsaved in-memory data."
  (let (dates)
    (maphash (lambda (date _dirty) (push date dates))
             daily-worklog--dirty-dates)
    dates))

;;;###autoload
(defun daily-worklog-save ()
  "Save accumulated worklog data without interrupting active timing."
  (interactive)
  (let* ((now (current-time))
         (today (daily-worklog--date-string now))
         (dates (cons today (daily-worklog--dirty-date-list))))
    (daily-worklog--checkpoint now t)
    ;; Checkpointing may have dirtied an additional date at midnight.
    (setq dates (append dates (daily-worklog--dirty-date-list)))
    (daily-worklog--save-dates dates now)
    (when (called-interactively-p 'interactive)
      (message "Daily worklog saved"))))

(defun daily-worklog--automatic-save ()
  "Save from a timer without allowing errors to stop future timers."
  (when daily-worklog--running-p
    (condition-case error-data
        (daily-worklog-save)
      (error
       (display-warning 'daily-worklog
                        (format "Automatic save failed: %s"
                                (error-message-string error-data))
                        :warning)))))

(defun daily-worklog--schedule-midnight ()
  "Schedule the next local-midnight save."
  (when (timerp daily-worklog--midnight-timer)
    (cancel-timer daily-worklog--midnight-timer))
  (setq daily-worklog--midnight-timer
        (run-at-time (daily-worklog--next-midnight (current-time))
                     nil #'daily-worklog--at-midnight)))

(defun daily-worklog--at-midnight ()
  "Save at local midnight and schedule the following rollover."
  (setq daily-worklog--midnight-timer nil)
  (when daily-worklog--running-p
    (unwind-protect
        (daily-worklog--automatic-save)
      (daily-worklog--schedule-midnight))))

(defun daily-worklog--format-duration (seconds)
  "Format SECONDS rounded to the nearest minute."
  (let* ((minutes (round (/ seconds 60.0)))
         (hours (/ minutes 60))
         (remainder (% minutes 60)))
    (if (> hours 0)
        (format "%dh %02dm" hours remainder)
      (format "%dm" remainder))))

(defun daily-worklog--empty-summary (date)
  "Return an empty report summary for DATE."
  `((date . ,date)
    (updatedAt . "")
    (totalSeconds . 0)
    (projects . [])))

(defun daily-worklog--display-summary (summary)
  "Display SUMMARY in a read-only report buffer and return that buffer."
  (let* ((date (alist-get 'date summary))
         (buffer (get-buffer-create (format "*Daily Worklog %s*" date))))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "Daily Worklog — %s\n\n" date))
        (insert (format "Total: %s\n"
                        (daily-worklog--format-duration
                         (alist-get 'totalSeconds summary))))
        (when-let* ((updated-at (alist-get 'updatedAt summary))
                    ((not (string-empty-p updated-at))))
          (insert (format "Updated: %s\n" updated-at)))
        (insert "\n")
        (if (= (length (alist-get 'projects summary)) 0)
            (insert "No recorded activity.\n")
          (seq-doseq (project (alist-get 'projects summary))
            (insert (format "%s — %s\n"
                            (alist-get 'name project)
                            (daily-worklog--format-duration
                             (alist-get 'totalSeconds project))))
            (when-let* ((root (alist-get 'root project)))
              (insert (format "  %s\n" root)))
            (seq-doseq (entry (alist-get 'buffers project))
              (insert (format "  %-32s %-24s %s\n"
                              (alist-get 'name entry)
                              (alist-get 'majorMode entry)
                              (daily-worklog--format-duration
                               (alist-get 'totalSeconds entry)))))
            (insert "\n")))
        (goto-char (point-min))
        (special-mode)))
    (pop-to-buffer buffer)
    buffer))

;;;###autoload
(defun daily-worklog-current-summary ()
  "Return today's in-memory summary, including the active interval.

This function performs no filesystem access."
  (let* ((now (current-time))
         (date (daily-worklog--date-string now)))
    (daily-worklog--checkpoint now t)
    (daily-worklog--summary-for-date date now)))

;;;###autoload
(defun daily-worklog-summary-for-date (date)
  "Return the available worklog summary for DATE, or nil.

DATE must use YYYY-MM-DD.  The returned value has the same shape as
`daily-worklog-current-summary'.  Unsaved in-memory totals are included, as
is the active interval when DATE is today.  This function never writes a
report.  Invalid dates and unreadable report files signal an error so callers
can distinguish unavailable data from a day with no recorded activity."
  (unless (daily-worklog--valid-date-p date)
    (user-error "Invalid date: %s" date))
  (let* ((now (current-time))
         (today (daily-worklog--date-string now))
         (active-today-p (and (string= date today)
                              daily-worklog--running-p))
         (persisted (when (file-exists-p (daily-worklog--date-file date))
                      ;; Read even when the date is already cached.  Besides
                      ;; returning persisted data this preserves the public
                      ;; contract that a corrupt report is reported as such.
                      (daily-worklog--read-summary date))))
    (when active-today-p
      ;; End and immediately resume the active interval.  This updates only
      ;; the in-memory aggregate; it neither saves nor interrupts tracking.
      (daily-worklog--checkpoint now t))
    (unless (gethash date daily-worklog--loaded-dates)
      (when persisted (daily-worklog--merge-summary persisted))
      ;; Do not cache a genuinely missing day.  If a report appears later in
      ;; the same session (for example after a midnight save), a later reader
      ;; should still discover it.
      (when (or persisted (gethash date daily-worklog--dates))
        (puthash date t daily-worklog--loaded-dates)))
    (if (or active-today-p
            persisted
            (gethash date daily-worklog--dates))
        (daily-worklog--summary-for-date date now)
      nil)))

;;;###autoload
(defun daily-worklog-show-date (date)
  "Display the worklog report for local DATE in YYYY-MM-DD form."
  (interactive
   (list (read-string "Daily worklog date (YYYY-MM-DD): "
                      (daily-worklog--date-string (current-time)))))
  (unless (daily-worklog--valid-date-p date)
    (user-error "Invalid date: %s" date))
  (let* ((today (daily-worklog--date-string (current-time)))
         (summary
          (if (and (string= date today)
                   (or daily-worklog--running-p
                       (gethash date daily-worklog--dates)))
              (daily-worklog-current-summary)
            (condition-case error-data
                (or (daily-worklog--read-summary date)
                    (daily-worklog--empty-summary date))
              (error
               (user-error "Could not read daily worklog for %s: %s"
                           date (error-message-string error-data)))))))
    (daily-worklog--display-summary summary)))

;;;###autoload
(defun daily-worklog-show-today ()
  "Display today's worklog report."
  (interactive)
  (daily-worklog-show-date
   (daily-worklog--date-string (current-time))))

;;;###autoload
(defun daily-worklog-reset-today ()
  "Clear today's in-memory and persisted worklog, then resume timing."
  (interactive)
  (when (or (not (called-interactively-p 'interactive))
            (yes-or-no-p "Reset today's daily worklog? "))
    (let* ((now (current-time))
           (today (daily-worklog--date-string now)))
      (daily-worklog--checkpoint now t)
      ;; Preserve any earlier-date portion of a midnight-spanning interval.
      (daily-worklog--save-dates
       (delete today (daily-worklog--dirty-date-list)) now)
      (let ((file (daily-worklog--date-file today)))
        (when (file-exists-p file)
          (delete-file file)))
      (remhash today daily-worklog--dates)
      (remhash today daily-worklog--dirty-dates)
      (puthash today t daily-worklog--loaded-dates)
      (when (called-interactively-p 'interactive)
        (message "Today's daily worklog reset")))))

(defun daily-worklog--kill-emacs-save ()
  "Save pending data before Emacs exits."
  (when daily-worklog--running-p
    (condition-case error-data
        (daily-worklog-save)
      (error
       (display-warning 'daily-worklog
                        (format "Exit save failed: %s"
                                (error-message-string error-data))
                        :warning)))))

(defun daily-worklog--install-runtime ()
  "Install hooks and timers, load today, and begin tracking."
  (unless daily-worklog--running-p
    (setq daily-worklog--running-p t)
    (daily-worklog--ensure-date-loaded
     (daily-worklog--date-string (current-time)))
    (add-hook 'window-buffer-change-functions
              #'daily-worklog--window-change)
    (add-hook 'window-selection-change-functions
              #'daily-worklog--window-change)
    (with-suppressed-warnings ((obsolete focus-out-hook focus-in-hook))
      (add-hook 'focus-out-hook #'daily-worklog--focus-out)
      (add-hook 'focus-in-hook #'daily-worklog--focus-in))
    (add-hook 'kill-emacs-hook #'daily-worklog--kill-emacs-save)
    (let ((interval (max 1 daily-worklog-save-interval)))
      (setq daily-worklog--save-timer
            (run-at-time interval interval
                         #'daily-worklog--automatic-save)))
    (daily-worklog--schedule-midnight)
    (setq daily-worklog--focused-p
          (not (null (frame-focus-state (selected-frame))))
          daily-worklog--selected-buffer nil)
    (when daily-worklog--focused-p
      (daily-worklog--select-buffer (window-buffer (selected-window))
                                    (current-time) t))))

(defun daily-worklog--remove-runtime ()
  "Save pending work and remove every hook and timer."
  (when daily-worklog--running-p
    (unwind-protect
        (condition-case error-data
            (daily-worklog-save)
          (error
           (display-warning 'daily-worklog
                            (format "Disable save failed: %s"
                                    (error-message-string error-data))
                            :warning)))
      (remove-hook 'window-buffer-change-functions
                   #'daily-worklog--window-change)
      (remove-hook 'window-selection-change-functions
                   #'daily-worklog--window-change)
      (with-suppressed-warnings ((obsolete focus-out-hook focus-in-hook))
        (remove-hook 'focus-out-hook #'daily-worklog--focus-out)
        (remove-hook 'focus-in-hook #'daily-worklog--focus-in))
      (remove-hook 'kill-emacs-hook #'daily-worklog--kill-emacs-save)
      (when (timerp daily-worklog--save-timer)
        (cancel-timer daily-worklog--save-timer))
      (when (timerp daily-worklog--midnight-timer)
        (cancel-timer daily-worklog--midnight-timer))
      (setq daily-worklog--save-timer nil
            daily-worklog--midnight-timer nil
            daily-worklog--selected-buffer nil
            daily-worklog--active-entry nil
            daily-worklog--interval-start nil
            daily-worklog--focused-p nil
            daily-worklog--running-p nil))))

;;;###autoload
(define-minor-mode daily-worklog-mode
  "Globally maintain approximate daily buffer and project time summaries."
  :global t
  :group 'daily-worklog
  (if daily-worklog-mode
      (daily-worklog--install-runtime)
    (daily-worklog--remove-runtime)))

(provide 'daily-worklog)

;;; daily-worklog.el ends here
