;;; org-notes.el --- Small native Org notes workflow  -*- lexical-binding: t; -*-

;;; Commentary:

;; Weekly Org capture, note search, task and habit agendas, attachments, and
;; daily-worklog summaries.  Org files remain the only notes/task store.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'org-agenda)
(require 'org-attach)
(require 'org-capture)
(require 'org-habit)
(require 'org-id)
(require 'seq)
(require 'subr-x)

(declare-function daily-worklog-show-date "daily-worklog" (date))
(declare-function daily-worklog-summary-for-date "daily-worklog" (date))
(declare-function helm-comp-read "helm" (prompt candidates &rest args))
(declare-function helm-do-ag "helm-ag" (&optional basedir targets query))

(defvar helm-ag-base-command)

(defgroup org-notes nil
  "Native Org notes, capture, and agenda helpers."
  :group 'org)

(defcustom org-notes-directory
  (expand-file-name "~/notes/org/")
  "Root directory containing personal Org notes.

Set this in the ignored var/org-notes-local.el for each machine."
  :type 'directory
  :group 'org-notes)

(defcustom org-notes-project-tag-prefix "project_"
  "Prefix identifying ordinary Org tags used as project tags."
  :type 'string
  :group 'org-notes)

(defconst org-notes--type-tags
  '("task" "note" "idea" "event" "meeting" "habit")
  "Tags reserved for capture types.")

(defvar org-notes--capture-active nil
  "Non-nil while an Org Notes capture buffer is being displayed.")

(defvar org-notes--note-title nil
  "Title being used for the current standalone note capture.")

(defvar-local org-notes--agenda-kind nil
  "Kind of Org Notes agenda displayed in the current buffer.")

(defvar-local org-notes--task-sort-mode 'deadline
  "Sort mode for the current Org Notes task dashboard.")

(defvar org-notes--worklog-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") #'org-notes-worklog-open-at-point)
    (define-key map (kbd "<return>") #'org-notes-worklog-open-at-point)
    (define-key map [mouse-1] #'org-notes-worklog-open-at-mouse)
    map)
  "Keymap placed on generated worklog rows.")

(defun org-notes--root ()
  "Return `org-notes-directory' as an absolute directory name."
  (file-name-as-directory (expand-file-name org-notes-directory)))

(defun org-notes--attachments-directory ()
  "Return the attachment root below `org-notes-directory'."
  (expand-file-name "attachments/" (org-notes--root)))

(defun org-notes--excluded-path-p (file)
  "Return non-nil when FILE is not an eligible note file."
  (let* ((relative (file-relative-name file (org-notes--root)))
         (parts (split-string relative "/" t)))
    (or (member "attachments" parts)
        (seq-some (lambda (part) (string-prefix-p "." part)) parts))))

;;;###autoload
(defun org-notes-files ()
  "Return all eligible Org files below `org-notes-directory'."
  (let ((root (org-notes--root)))
    (if (file-directory-p root)
        (seq-remove #'org-notes--excluded-path-p
                    (directory-files-recursively root "\\.org\\'"))
      nil)))

(defun org-notes--iso-week-name (&optional time)
  "Return ISO week basename for TIME, defaulting to now."
  (format-time-string "%G-W%V" time))

(defun org-notes-weekly-file (&optional time)
  "Return the weekly capture file for TIME, defaulting to now."
  (expand-file-name
   (concat "weekly/" (org-notes--iso-week-name time) ".org")
   (org-notes--root)))

(defun org-notes--slug (title)
  "Return a filesystem-friendly slug for TITLE."
  (let ((slug (replace-regexp-in-string
               "-+" "-"
               (replace-regexp-in-string "[^[:alnum:]]+" "-"
                                         (downcase (string-trim title))))))
    (string-trim slug "-" "-")))

(defun org-notes--unique-file (directory basename)
  "Return an unused Org file below DIRECTORY for BASENAME."
  (let ((candidate (expand-file-name (concat basename ".org") directory))
        (number 2))
    (while (file-exists-p candidate)
      (setq candidate
            (expand-file-name (format "%s-%d.org" basename number) directory)
            number (1+ number)))
    candidate))

(defun org-notes--standalone-note-file (title &optional time)
  "Return a collision-safe standalone note path for TITLE and TIME."
  (let* ((directory (expand-file-name "notes/" (org-notes--root)))
         (slug (org-notes--slug title))
         (basename (concat (format-time-string "%Y-%m-%d-%H%M" time)
                           "--" (if (string-empty-p slug) "note" slug))))
    (org-notes--unique-file directory basename)))

(defun org-notes--day-heading (&optional time)
  "Return the capture day heading for TIME, defaulting to now."
  (format-time-string "%Y-%m-%d %A" time))

(defun org-notes--capture-target ()
  "Visit this week's file and move to today's top-level heading."
  (let* ((time (current-time))
         (file (org-notes-weekly-file time))
         (heading (org-notes--day-heading time)))
    (make-directory (file-name-directory file) t)
    (set-buffer (find-file-noselect file))
    (unless (derived-mode-p 'org-mode) (org-mode))
    (widen)
    (when (= (buffer-size) 0)
      (insert (format "#+title: Week %s\n#+startup: overview\n\n"
                      (org-notes--iso-week-name time))))
    (goto-char (point-min))
    (if (re-search-forward
         (format "^\\* %s[ \t]*$" (regexp-quote heading)) nil t)
        (beginning-of-line)
      (goto-char (point-max))
      (unless (bolp) (insert "\n"))
      (insert "* " heading "\n")
      (forward-line -1))))

(defun org-notes--habit-capture-target ()
  "Visit the dedicated habits file for a top-level habit capture."
  (let ((file (expand-file-name "habits.org" (org-notes--root))))
    (make-directory (file-name-directory file) t)
    (set-buffer (find-file-noselect file))
    (unless (derived-mode-p 'org-mode) (org-mode))
    (widen)
    (when (= (buffer-size) 0)
      (insert "#+title: Habits\n#+startup: overview\n\n"))
    (goto-char (point-max))))

(defun org-notes--note-capture-target ()
  "Visit the new standalone Org file selected by the note template."
  (unless (and org-notes--note-title
               (not (string-empty-p org-notes--note-title)))
    (user-error "A standalone note needs a title"))
  (let ((file (org-notes--standalone-note-file org-notes--note-title)))
    (make-directory (file-name-directory file) t)
    (set-buffer (find-file-noselect file))
    (unless (derived-mode-p 'org-mode) (org-mode))
    (widen)
    (goto-char (point-min))
    (insert "#+title: " org-notes--note-title
            "\n#+startup: overview\n\n")))

(defun org-notes--project-tag-name (project)
  "Convert PROJECT entered by the user into a valid project tag."
  (when-let* ((name (string-trim project))
              ((not (string-empty-p name))))
    (concat org-notes-project-tag-prefix
            (replace-regexp-in-string
             "_+" "_"
             (replace-regexp-in-string "[^[:alnum:]_@#%]" "_"
                                       (downcase name))))))

(defun org-notes--project-display-name (tag)
  "Return a friendly project name for project TAG."
  (replace-regexp-in-string
   "_" " " (string-remove-prefix org-notes-project-tag-prefix tag)))

(defun org-notes--project-tags ()
  "Return sorted project tags found in all note files."
  (let (tags)
    (dolist (file (org-notes-files))
      (with-current-buffer (find-file-noselect file t)
        (org-with-wide-buffer
         (org-map-entries
          (lambda ()
            (dolist (tag (org-get-tags nil t))
              (when (string-prefix-p org-notes-project-tag-prefix tag)
                (cl-pushnew tag tags :test #'equal))))))))
    (sort tags #'string-lessp)))

(defun org-notes--read-project-tag ()
  "Prompt for an optional existing or new project tag."
  (let* ((tags (org-notes--project-tags))
         (names (mapcar #'org-notes--project-display-name tags))
         (answer (completing-read "Project (empty for none): " names nil nil)))
    (org-notes--project-tag-name answer)))

(defun org-notes--tag-suffix (kind project)
  "Return heading tag suffix for capture KIND and PROJECT."
  (format " :%s%s:"
          kind
          (if project (concat ":" project) "")))

(defun org-notes--capture-template (kind &optional todo occurrence habit body-point)
  "Build capture template for KIND.

When TODO is non-nil add the TODO keyword.  OCCURRENCE adds an active
occurrence timestamp.  HABIT adds native Org habit metadata and a daily
repeater.  BODY-POINT places the editing cursor in the body."
  (let ((project (org-notes--read-project-tag)))
    (concat "* " (if todo "TODO " "")
            (if body-point org-notes--note-title "%?")
            (org-notes--tag-suffix kind project) "\n"
            (when habit
              (concat "SCHEDULED: <%<%Y-%m-%d %a> .+1d>\n"
                      ":PROPERTIES:\n:STYLE: habit\n"
                      ":LOGGING: logrepeat\n:END:\n"))
            "Captured: %U\n"
            (when occurrence "Occurs: %T\n")
            (when body-point "\n%?")
            "%i")))

(defun org-notes--task-template ()
  "Return the task capture template."
  (org-notes--capture-template "task" t))

(defun org-notes--note-template ()
  "Return the note capture template."
  (setq org-notes--note-title (string-trim (read-string "Note title: ")))
  (when (string-empty-p org-notes--note-title)
    (user-error "A standalone note needs a title"))
  (org-notes--capture-template "note" nil nil nil t))

(defun org-notes--idea-template ()
  "Return the idea capture template."
  (org-notes--capture-template "idea"))

(defun org-notes--event-template ()
  "Return the event capture template."
  (org-notes--capture-template "event" nil t))

(defun org-notes--meeting-template ()
  "Return the meeting capture template."
  (org-notes--capture-template "meeting" nil t))

(defun org-notes--habit-template ()
  "Return the habit capture template."
  (org-notes--capture-template "habit" t nil t))

(defconst org-notes-capture-templates
  '(("t" "Task" entry (function org-notes--capture-target)
     (function org-notes--task-template) :empty-lines 1)
    ("n" "Note" entry (function org-notes--note-capture-target)
     (function org-notes--note-template) :empty-lines 1 :kill-buffer t)
    ("i" "Idea" entry (function org-notes--capture-target)
     (function org-notes--idea-template) :empty-lines 1)
    ("e" "Event" entry (function org-notes--capture-target)
     (function org-notes--event-template) :empty-lines 1)
    ("m" "Meeting" entry (function org-notes--capture-target)
     (function org-notes--meeting-template) :empty-lines 1)
    ("h" "Habit" entry (function org-notes--habit-capture-target)
     (function org-notes--habit-template) :empty-lines 1))
  "Capture templates installed by `org-notes-setup'.")

(defun org-notes--right-window ()
  "Return the reusable right-hand ordinary window, creating it if needed."
  (let* ((ordinary (seq-remove
                    (lambda (window) (window-parameter window 'window-side))
                    (window-list nil 'no-minibuffer)))
         (rightmost
          (car (sort (copy-sequence ordinary)
                     (lambda (left right)
                       (> (car (window-edges left))
                          (car (window-edges right))))))))
    (cond
     ;; Reuse an existing side-by-side layout.
     ((and (> (length ordinary) 1)
           (> (apply #'max (mapcar (lambda (window)
                                     (car (window-edges window)))
                                   ordinary))
              (apply #'min (mapcar (lambda (window)
                                     (car (window-edges window)))
                                   ordinary))))
      rightmost)
     ;; Replace a stacked layout, then make an explicit left/right split.  An
     ;; explicit direction avoids `split-width-threshold' changing the shape.
     (t
      (when (> (length ordinary) 1)
        (delete-other-windows))
      (condition-case nil
          (split-window (selected-window) nil 'right)
        (error (selected-window)))))))

(defun org-notes--display-in-right (buffer)
  "Display BUFFER in the reusable right-hand window and select it."
  (let ((window (org-notes--right-window)))
    (set-window-buffer window buffer)
    (select-window window)
    window))

(defun org-notes--open-agenda-in-right (command &optional start-day)
  "Run agenda COMMAND and show it in the right pane.

START-DAY, when non-nil, is bound as `org-agenda-start-day'.  The temporary
window arrangement created internally by Org is discarded before displaying
the finished agenda."
  (let ((configuration (current-window-configuration))
        (org-agenda-files (org-notes--agenda-files))
        (org-agenda-start-day (or start-day org-agenda-start-day))
        agenda-buffer)
    (org-agenda nil command)
    (setq agenda-buffer (current-buffer))
    (set-window-configuration configuration)
    (org-notes--display-in-right agenda-buffer)))

(defun org-notes--capture-display-advice (original buffer alist)
  "Use the right pane for Org Notes capture, otherwise call ORIGINAL.

BUFFER and ALIST are the action-function arguments used by Org."
  (if org-notes--capture-active
      (org-notes--display-in-right buffer)
    (funcall original buffer alist)))

;;;###autoload
(defun org-notes-capture ()
  "Start an Org Notes capture using `org-notes-capture-templates'."
  (interactive)
  (let ((org-notes--capture-active t)
        (org-notes--note-title nil)
        (org-capture-templates org-notes-capture-templates))
    (org-capture)))

;;;###autoload
(defun org-notes-search ()
  "Search note contents recursively with the configured Helm/ripgrep UI."
  (interactive)
  (unless (file-directory-p (org-notes--root))
    (user-error "Notes directory does not exist: %s" (org-notes--root)))
  (require 'helm-ag)
  (let ((helm-ag-base-command
         (concat helm-ag-base-command
                 " --glob=*.org --glob=!attachments/** --glob=!.git/**")))
    (helm-do-ag (org-notes--root) nil "")))

;;;###autoload
(defun org-notes-find-file ()
  "Find an Org note recursively by filename using Helm completion."
  (interactive)
  (let* ((files (org-notes-files))
         (candidates
          (mapcar (lambda (file)
                    (cons (file-relative-name file (org-notes--root)) file))
                  files)))
    (unless candidates (user-error "No Org notes found"))
    (require 'helm)
    (find-file (helm-comp-read "Org note: " candidates
                               :must-match t :name "Org notes"))))

(defun org-notes--agenda-files ()
  "Return fresh agenda files and fail helpfully when there are none."
  (or (org-notes-files)
      (user-error "No Org notes found under %s" (org-notes--root))))

(defun org-notes--monday-start ()
  "Return an Org agenda start-day offset for the current Monday."
  (format "-%dd" (1- (string-to-number (format-time-string "%u")))))

(defun org-notes--source-line-at (marker)
  "Return source line text at MARKER, or nil."
  (when (and (markerp marker) (marker-buffer marker))
    (with-current-buffer (marker-buffer marker)
      (save-excursion
        (goto-char marker)
        (buffer-substring-no-properties
         (line-beginning-position) (line-end-position))))))

(defun org-notes--agenda-heading-title ()
  "Return plain source heading title for the agenda row at point."
  (when-let* ((marker (or (get-text-property (point) 'org-hd-marker)
                           (get-text-property (point) 'org-marker)))
              ((markerp marker))
              ((marker-buffer marker)))
    (with-current-buffer (marker-buffer marker)
      (save-excursion
        (goto-char marker)
        (when (org-back-to-heading t)
          (org-get-heading t t t t))))))

(defun org-notes--annotate-activity-rows ()
  "Label capture, occurrence, and repeat rows; remove duplicate CLOSED rows."
  (let ((inhibit-read-only t))
    (goto-char (point-max))
    (while (not (bobp))
      (forward-line -1)
      (when-let* ((marker (get-text-property (point) 'org-marker))
                  (source (org-notes--source-line-at marker)))
        (let ((end (line-end-position))
              (extra (get-text-property (point) 'extra)))
          (cond
           ((and (string-prefix-p "CLOSED:" (string-trim-left source))
                 (equal extra "["))
            (delete-region (line-beginning-position)
                           (min (point-max) (1+ end))))
           ((string-prefix-p "Captured:" (string-trim-left source))
            (when (re-search-forward "\\[ " end t)
              (replace-match "Captured: " t t)))
           ((string-prefix-p "- State \"DONE\"" (string-trim-left source))
            (when-let ((title (org-notes--agenda-heading-title)))
              (when (search-forward title end t)
                (backward-char (length title))
                (when (re-search-backward
                       "\\_<\\(?:TODO\\|PROG\\)\\_> "
                       (line-beginning-position) t)
                  (goto-char (match-beginning 0)))
                (insert "Completed: "))))
           ((string-prefix-p "Occurs:" (string-trim-left source))
            (when-let ((title (org-notes--agenda-heading-title)))
              (when (search-forward title end t)
                (backward-char (length title))
                (insert "Occurs: "))))))))))

(defun org-notes--format-duration (seconds)
  "Format SECONDS as a compact rounded duration."
  (let* ((minutes (round (/ seconds 60.0)))
         (hours (/ minutes 60))
         (remaining (% minutes 60)))
    (cond
     ((and (> hours 0) (> remaining 0)) (format "%dh %dm" hours remaining))
     ((> hours 0) (format "%dh" hours))
     (t (format "%dm" remaining)))))

(defun org-notes--worklog-text (date)
  "Return a display string for DATE's worklog."
  (condition-case _error
      (if-let* ((summary (daily-worklog-summary-for-date date)))
          (let ((total (alist-get 'totalSeconds summary))
                projects)
            (seq-doseq (project (alist-get 'projects summary))
              (when (> (alist-get 'totalSeconds project) 0)
                (push (format "%s %s"
                              (alist-get 'name project)
                              (org-notes--format-duration
                               (alist-get 'totalSeconds project)))
                      projects)))
            (concat "Worklog: " (org-notes--format-duration total)
                    (when projects
                      (concat " — " (string-join (nreverse projects) ", ")))))
        "Worklog: No recorded activity")
    (error "Worklog: unavailable")))

(defun org-notes--absolute-date-string (absolute)
  "Convert ABSOLUTE day number to YYYY-MM-DD."
  (pcase-let ((`(,month ,day ,year)
               (calendar-gregorian-from-absolute absolute)))
    (format "%04d-%02d-%02d" year month day)))

(defun org-notes--insert-worklog-rows ()
  "Insert one generated worklog row below each agenda date heading."
  (let ((inhibit-read-only t)
        date-lines)
    ;; Agenda refresh normally rebuilds the buffer.  Removing any generated
    ;; rows here also makes manual finalization harmless and idempotent.
    (goto-char (point-max))
    (while (not (bobp))
      (forward-line -1)
      (when (get-text-property (point) 'org-notes-worklog-date)
        (delete-region (line-beginning-position)
                       (min (point-max) (1+ (line-end-position))))))
    (goto-char (point-min))
    (while (not (eobp))
      (when-let* ((absolute (get-text-property (point) 'day))
                  ((get-text-property (point) 'org-date-line)))
        (push (cons (copy-marker (line-end-position))
                    (org-notes--absolute-date-string absolute))
              date-lines))
      (forward-line 1))
    ;; DATE-LINES is already bottom-to-top, so insertions cannot invalidate
    ;; positions still to be visited.
    (dolist (entry date-lines)
      (let* ((marker (car entry))
             (date (cdr entry))
             (text (concat "  " (org-notes--worklog-text date) "\n")))
        (goto-char marker)
        (forward-line 1)
        (insert (propertize text
                            'day nil
                            'org-date-line nil
                            'org-notes-worklog-date date
                            'face 'shadow
                            'mouse-face 'highlight
                            'help-echo "RET: open detailed daily worklog"
                            'keymap org-notes--worklog-map))
        (set-marker marker nil)))))

(defun org-notes--finalize-activity ()
  "Finalize an Org Notes weekly activity agenda."
  (setq-local org-notes--agenda-kind 'activity)
  (org-notes--annotate-activity-rows)
  (org-notes--insert-worklog-rows))

(defun org-notes--finalize-tasks ()
  "Finalize an Org Notes open-task dashboard."
  (setq-local org-notes--agenda-kind 'tasks)
  (unless (local-variable-p 'org-notes--task-sort-mode)
    (setq-local org-notes--task-sort-mode 'deadline)))

(defun org-notes--finalize-habits ()
  "Finalize an Org Notes habit dashboard."
  (setq-local org-notes--agenda-kind 'habits))

(defun org-notes--finalize-dashboard ()
  "Mark the combined Org Notes dashboard for source navigation and refresh."
  (setq-local org-notes--agenda-kind 'dashboard))

(defun org-notes--skip-habit-or-archived ()
  "Skip the current entry when it is a habit or archived."
  (when (or (org-in-archived-heading-p)
            (equal (org-entry-get nil "STYLE") "habit"))
    (or (outline-next-heading) (point-max))))

(defun org-notes--skip-non-habit ()
  "Skip the current entry unless it is an active habit."
  (unless (and (not (org-in-archived-heading-p))
               (equal (org-entry-get nil "STYLE") "habit")
               (member (org-get-todo-state) org-not-done-keywords))
    (or (outline-next-heading) (point-max))))

(defun org-notes--marker-value (agenda-line getter)
  "Call GETTER at AGENDA-LINE's source marker."
  (when-let* ((marker (or (get-text-property 0 'org-marker agenda-line)
                           (get-text-property 1 'org-marker agenda-line)))
              ((marker-buffer marker)))
    (with-current-buffer (marker-buffer marker)
      (save-excursion
        (goto-char marker)
        (funcall getter)))))

(defun org-notes--entry-project-tag (agenda-line)
  "Return project tag for AGENDA-LINE, or nil."
  (org-notes--marker-value
   agenda-line
   (lambda ()
     (seq-find (lambda (tag)
                 (string-prefix-p org-notes-project-tag-prefix tag))
               (org-get-tags nil t)))))

(defun org-notes--entry-ordinary-tag (agenda-line)
  "Return first non-reserved tag for AGENDA-LINE, or nil."
  (org-notes--marker-value
   agenda-line
   (lambda ()
     (seq-find
      (lambda (tag)
        (and (not (member tag org-notes--type-tags))
             (not (member tag '("ARCHIVE" "ATTACH")))
             (not (string-prefix-p org-notes-project-tag-prefix tag))))
      (sort (copy-sequence (org-get-tags nil t)) #'string-lessp)))))

(defun org-notes--entry-deadline (agenda-line)
  "Return absolute deadline day for AGENDA-LINE, or nil."
  (org-notes--marker-value
   agenda-line
   (lambda ()
     (when-let ((deadline (org-entry-get nil "DEADLINE")))
       (org-time-string-to-absolute deadline)))))

(defun org-notes--compare-values (left right &optional missing-last)
  "Compare LEFT and RIGHT, returning -1, 1, or nil.

When MISSING-LAST is non-nil, nil values sort after non-nil values."
  (cond
   ((equal left right) nil)
   ((null left) (if missing-last 1 -1))
   ((null right) (if missing-last -1 1))
   ((and (numberp left) (numberp right)) (if (< left right) -1 1))
   ((string-lessp (downcase left) (downcase right)) -1)
   (t 1)))

(defun org-notes--task-agenda-compare (left right)
  "Compare task agenda strings LEFT and RIGHT using the selected mode."
  (pcase org-notes--task-sort-mode
    ('project
     (org-notes--compare-values (org-notes--entry-project-tag left)
                                (org-notes--entry-project-tag right) t))
    ('tag
     (org-notes--compare-values (org-notes--entry-ordinary-tag left)
                                (org-notes--entry-ordinary-tag right) t))
    (_
     (org-notes--compare-values (org-notes--entry-deadline left)
                                (org-notes--entry-deadline right) t))))

(defun org-notes--install-agenda-commands ()
  "Install the private custom agenda commands used by Org Notes."
  (dolist (command
           '(("NW" "Org Notes weekly activity" agenda ""
              ((org-agenda-span 7)
               (org-agenda-start-on-weekday 1)
               (org-agenda-overriding-header
                "Weekly activity — C-c [ previous week, C-c ] next week")
               (org-agenda-show-all-dates t)
               (org-agenda-include-inactive-timestamps t)
               (org-agenda-start-with-log-mode t)
               (org-agenda-log-mode-items '(closed))
               (org-agenda-finalize-hook '(org-notes--finalize-activity))))
             ("NN" "Org Notes open tasks" todo "TODO|PROG"
              ((org-agenda-overriding-header
                "Open tasks — C-c s: sort, /: filter by tag")
               (org-agenda-skip-function 'org-notes--skip-habit-or-archived)
               (org-agenda-sorting-strategy '(user-defined-up))
               (org-agenda-cmp-user-defined 'org-notes--task-agenda-compare)
               (org-agenda-finalize-hook '(org-notes--finalize-tasks))))
             ("NH" "Org Notes habits" agenda ""
              ((org-agenda-span 1)
               (org-agenda-overriding-header "Habits")
               (org-agenda-skip-function 'org-notes--skip-non-habit)
               (org-habit-show-all-today t)
               (org-habit-show-habits-only-for-today t)
               (org-agenda-finalize-hook '(org-notes--finalize-habits))))
             ("ND" "Org Notes dashboard"
              ((agenda ""
                       ((org-agenda-span 1)
                        (org-agenda-overriding-header "Habits today")
                        (org-agenda-skip-function 'org-notes--skip-non-habit)
                        (org-habit-show-all-today t)
                        (org-habit-show-habits-only-for-today t)
                        (org-agenda-use-time-grid nil)))
               (agenda ""
                       ((org-agenda-span 7)
                        (org-agenda-start-on-weekday nil)
                        (org-agenda-overriding-header
                         "Next 7 days — scheduled, deadlines, events")
                        (org-agenda-skip-function
                         'org-notes--skip-habit-or-archived)
                        (org-agenda-include-inactive-timestamps nil)
                        (org-agenda-start-with-log-mode nil)
                        (org-agenda-use-time-grid nil)))
               (todo "TODO|PROG"
                     ((org-agenda-overriding-header "Open tasks")
                      (org-agenda-skip-function
                       'org-notes--skip-habit-or-archived)
                      (org-agenda-sorting-strategy '(user-defined-up))
                      (org-agenda-cmp-user-defined
                       'org-notes--task-agenda-compare))))
              ((org-agenda-compact-blocks nil)
               (org-agenda-finalize-hook '(org-notes--finalize-dashboard))))))
    (setq org-agenda-custom-commands
          (cons command
                (seq-remove (lambda (entry)
                              (equal (car entry) (car command)))
                            org-agenda-custom-commands)))))

;;;###autoload
(defun org-notes-weekly-activity ()
  "Open the current Monday-to-Sunday activity agenda."
  (interactive)
  (org-notes--open-agenda-in-right "NW" (org-notes--monday-start)))

;;;###autoload
(defun org-notes-tasks ()
  "Open the dashboard of unfinished non-habit tasks."
  (interactive)
  (when-let ((buffer (get-buffer "*Org Agenda*")))
    (with-current-buffer buffer
      (kill-local-variable 'org-notes--task-sort-mode)))
  (org-notes--open-agenda-in-right "NN"))

;;;###autoload
(defun org-notes-habits ()
  "Open today's native Org habit dashboard."
  (interactive)
  (org-notes--open-agenda-in-right "NH"))

;;;###autoload
(defun org-notes-dashboard ()
  "Open habits, upcoming dates, and open tasks in one Org Agenda."
  (interactive)
  (org-notes--open-agenda-in-right "ND"))

;;;###autoload
(defun org-notes-task-sort (sort)
  "Sort the current task dashboard by SORT and refresh it."
  (interactive
   (list (intern
          (downcase
           (completing-read "Sort open tasks by: "
                            '("Deadline" "Project" "Tag") nil t nil nil
                            (capitalize (symbol-name org-notes--task-sort-mode)))))))
  (unless (eq org-notes--agenda-kind 'tasks)
    (user-error "This sort command is only available in the task dashboard"))
  (setq-local org-notes--task-sort-mode sort)
  (org-notes-agenda-redo)
  (message "Tasks sorted by %s" (symbol-name sort)))

;;;###autoload
(defun org-notes-agenda-redo ()
  "Refresh an agenda, discovering new Org Notes files when appropriate."
  (interactive)
  (if org-notes--agenda-kind
      (let ((org-agenda-files (org-notes-files)))
        (org-agenda-redo))
    (org-agenda-redo)))

(defun org-notes--agenda-source-marker ()
  "Return a usable source marker for the current agenda row."
  (or (get-text-property (point) 'org-hd-marker)
      (get-text-property (point) 'org-marker)
      (user-error "No Org entry on this line")))

;;;###autoload
(defun org-notes-agenda-open ()
  "Open the current Org Notes agenda entry in the reusable right pane."
  (interactive)
  (if (not org-notes--agenda-kind)
      (org-agenda-switch-to)
    (let* ((marker (org-notes--agenda-source-marker))
           (buffer (marker-buffer marker))
           (position (marker-position marker)))
      (org-notes--display-in-right buffer)
      (widen)
      (goto-char position)
      (org-back-to-heading t)
      (org-fold-show-context 'agenda))))

(defun org-notes--ensure-org-heading ()
  "Move from an Org Notes agenda to its source and require a heading."
  (when (derived-mode-p 'org-agenda-mode)
    (org-notes-agenda-open))
  (unless (derived-mode-p 'org-mode)
    (user-error "This command needs an Org heading or Org Notes agenda item"))
  (unless (org-before-first-heading-p)
    (org-back-to-heading t))
  (when (org-before-first-heading-p)
    (user-error "Place point inside an Org heading first")))

(defun org-notes--link-insertion-point ()
  "Move to a useful attachment-link position at the current entry."
  (org-end-of-meta-data t)
  (unless (bolp) (insert "\n")))

;;;###autoload
(defun org-notes-attach-file (file)
  "Copy FILE into the current entry's attachment directory and insert a link."
  (interactive "fFile to attach: ")
  (org-notes--ensure-org-heading)
  (let ((basename (file-name-nondirectory (directory-file-name file))))
    (let ((org-attach-id-dir (org-notes--attachments-directory)))
      (org-id-get-create))
    (let ((org-attach-id-dir (org-notes--attachments-directory))
          (org-attach-method 'cp)
          (org-attach-store-link-p nil))
      (org-attach-attach file nil 'cp))
    (org-notes--link-insertion-point)
    (insert (org-link-make-string (concat "attachment:" basename) basename)
            "\n")
    (save-buffer)))

;;;###autoload
(defun org-notes-paste-image ()
  "Paste a clipboard image into the current entry as an Org attachment."
  (interactive)
  (org-notes--ensure-org-heading)
  (let ((org-attach-id-dir (org-notes--attachments-directory)))
    (org-id-get-create))
  (org-notes--link-insertion-point)
  (let ((org-attach-id-dir (org-notes--attachments-directory))
        (org-yank-image-save-method 'attach))
    (call-interactively #'yank-media))
  (when (derived-mode-p 'org-mode)
    (org-display-inline-images)))

;;;###autoload
(defun org-notes-worklog-open-at-point ()
  "Open the detailed worklog represented by the row at point."
  (interactive)
  (when-let ((date (get-text-property (point) 'org-notes-worklog-date)))
    (daily-worklog-show-date date)))

(defun org-notes-worklog-open-at-mouse (event)
  "Open the worklog row clicked by mouse EVENT."
  (interactive "e")
  (mouse-set-point event)
  (org-notes-worklog-open-at-point))

;;;###autoload
(defun org-notes-setup ()
  "Install Org Notes capture, agenda, attachment, and display integration."
  (setq org-capture-templates org-notes-capture-templates
        org-attach-id-dir (org-notes--attachments-directory)
        org-attach-method 'cp
        org-attach-preferred-new-method 'id
        org-yank-image-save-method 'attach
        org-log-repeat 'time)
  (org-notes--install-agenda-commands)
  (unless (advice-member-p #'org-notes--capture-display-advice
                           #'org-display-buffer-split)
    (advice-add #'org-display-buffer-split :around
                #'org-notes--capture-display-advice))
  (define-key org-agenda-mode-map (kbd "C-c s") #'org-notes-task-sort)
  (define-key org-agenda-mode-map (kbd "C-c [") #'org-agenda-earlier)
  (define-key org-agenda-mode-map (kbd "C-c ]") #'org-agenda-later)
  (define-key org-agenda-mode-map (kbd "g") #'org-notes-agenda-redo)
  (define-key org-agenda-mode-map (kbd "RET") #'org-notes-agenda-open)
  (define-key org-agenda-mode-map (kbd "<return>") #'org-notes-agenda-open))

(provide 'org-notes)
;;; org-notes.el ends here
