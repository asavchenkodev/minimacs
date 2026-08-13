;;; daily-worklog-test.el --- Tests for daily-worklog  -*- lexical-binding: t; -*-

;;; Commentary:

;; Isolated ERT coverage for the single-file daily-worklog package.

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'json)
(require 'daily-worklog)

(defun daily-worklog-test--reset-state ()
  "Remove package runtime state without performing a save."
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
  (setq daily-worklog-mode nil
        daily-worklog--running-p nil
        daily-worklog--focused-p nil
        daily-worklog--selected-buffer nil
        daily-worklog--active-entry nil
        daily-worklog--interval-start nil
        daily-worklog--save-timer nil
        daily-worklog--midnight-timer nil
        daily-worklog--dates (make-hash-table :test #'equal)
        daily-worklog--loaded-dates (make-hash-table :test #'equal)
        daily-worklog--dirty-dates (make-hash-table :test #'equal)))

(defmacro daily-worklog-test--with-clean-state (&rest body)
  "Run BODY with isolated package state and persistence."
  (declare (indent 0) (debug t))
  `(let ((daily-worklog-directory
          (make-temp-file "daily-worklog-test-" t))
         (daily-worklog-ignored-buffer-regexp
          "\\`\\(?:\\*Messages\\*\\|\\*Completions\\*\\)\\'")
         (daily-worklog-track-remote-buffers nil)
         (daily-worklog-save-interval 3600))
     (unwind-protect
         (progn
           (daily-worklog-test--reset-state)
           ,@body)
       (daily-worklog-test--reset-state)
       (delete-directory daily-worklog-directory t))))

(defun daily-worklog-test--time-add (time seconds)
  "Return TIME advanced by SECONDS."
  (time-add time (seconds-to-time seconds)))

(defun daily-worklog-test--entry (buffer project root)
  "Return a test entry for BUFFER in PROJECT at ROOT."
  (daily-worklog--make-entry
   :buffer buffer
   :name (buffer-name buffer)
   :major-mode (with-current-buffer buffer (symbol-name major-mode))
   :project-name project
   :project-root root))

(defun daily-worklog-test--projects (summary)
  "Return SUMMARY's projects as a list."
  (append (alist-get 'projects summary) nil))

(defun daily-worklog-test--buffers (project)
  "Return PROJECT's buffers as a list."
  (append (alist-get 'buffers project) nil))

(ert-deftest daily-worklog-switching-aggregates-and-deduplicates-in-memory ()
  (daily-worklog-test--with-clean-state
    (let* ((start (encode-time 0 0 10 10 8 2026))
           (first (generate-new-buffer "commands.rs"))
           (second (generate-new-buffer "ActivityView.tsx"))
           (writes 0))
      (unwind-protect
          (progn
            (with-current-buffer first (setq major-mode 'rust-mode))
            (with-current-buffer second
              (setq major-mode 'typescript-ts-mode))
            (setq daily-worklog--running-p t
                  daily-worklog--focused-p t)
            (cl-letf (((symbol-function 'daily-worklog--resolve-project)
                       (lambda (_buffer)
                         '(:name "planner"
                           :root "/Users/asv/projects/planner")))
                      ((symbol-function 'daily-worklog--write-summary)
                       (lambda (_summary) (cl-incf writes))))
              (daily-worklog--select-buffer first start)
              (daily-worklog--select-buffer
               first (daily-worklog-test--time-add start 5))
              (daily-worklog--select-buffer
               second (daily-worklog-test--time-add start 10))
              (daily-worklog--checkpoint
               (daily-worklog-test--time-add start 20) nil))
            (let* ((summary (daily-worklog--summary-for-date
                             "2026-08-10"
                             (daily-worklog-test--time-add start 20)))
                   (project (car (daily-worklog-test--projects summary)))
                   (buffers (daily-worklog-test--buffers project)))
              (should (= 20 (alist-get 'totalSeconds summary)))
              (should (= 2 (length buffers)))
              (should (= 10 (alist-get 'totalSeconds (nth 0 buffers))))
              (should (= 10 (alist-get 'totalSeconds (nth 1 buffers))))
              (should (= writes 0))))
        (kill-buffer first)
        (kill-buffer second)))))

(ert-deftest daily-worklog-filtering-excludes-only-requested-noise ()
  (daily-worklog-test--with-clean-state
    (let ((hidden (generate-new-buffer " hidden-worklog-test"))
          (messages (get-buffer-create "*Messages*"))
          (compilation (generate-new-buffer "*compilation*"))
          (remote (generate-new-buffer "remote-worklog-test")))
      (unwind-protect
          (progn
            (with-current-buffer remote
              (setq default-directory "/ssh:example.invalid:/tmp/"))
            (should-not (daily-worklog--trackable-buffer-p hidden))
            (should-not (daily-worklog--trackable-buffer-p messages))
            (should (daily-worklog--trackable-buffer-p compilation))
            (should-not (daily-worklog--trackable-buffer-p remote))
            (let ((daily-worklog-track-remote-buffers t))
              (should (daily-worklog--trackable-buffer-p remote)))
            (should-not
             (daily-worklog--trackable-buffer-p
              (window-buffer (minibuffer-window)))))
        (kill-buffer hidden)
        (kill-buffer compilation)
        (kill-buffer remote)))))

(ert-deftest daily-worklog-focus-stops-and-resumes-idempotently ()
  (daily-worklog-test--with-clean-state
    (let* ((start (encode-time 0 0 10 10 8 2026))
           (now start)
           (buffer (generate-new-buffer "focus-worklog-test")))
      (unwind-protect
          (save-window-excursion
            (switch-to-buffer buffer)
            (setq daily-worklog--running-p t
                  daily-worklog--focused-p t)
            (cl-letf (((symbol-function 'current-time) (lambda () now))
                      ((symbol-function 'daily-worklog--resolve-project)
                       (lambda (_buffer)
                         '(:name "focus" :root "/tmp/focus"))))
              (daily-worklog--select-buffer buffer start)
              (setq now (daily-worklog-test--time-add start 10))
              (daily-worklog--focus-out)
              (should-not daily-worklog--active-entry)
              (setq now (daily-worklog-test--time-add start 20))
              (daily-worklog--focus-out)
              (setq now (daily-worklog-test--time-add start 30))
              (daily-worklog--focus-in)
              (setq now (daily-worklog-test--time-add start 35))
              (daily-worklog--focus-in)
              (daily-worklog--checkpoint
               (daily-worklog-test--time-add start 40) nil))
            (should (= 20
                       (alist-get
                        'totalSeconds
                        (daily-worklog--summary-for-date
                         "2026-08-10"
                         (daily-worklog-test--time-add start 40))))))
        (kill-buffer buffer)))))

(ert-deftest daily-worklog-window-handler-tracks-selection-not-other-window ()
  (daily-worklog-test--with-clean-state
    (let* ((start (encode-time 0 0 10 10 8 2026))
           (now start)
           (first (generate-new-buffer "window-one-worklog-test"))
           (second (generate-new-buffer "window-two-worklog-test"))
           (noise (generate-new-buffer "window-noise-worklog-test")))
      (unwind-protect
          (save-window-excursion
            (delete-other-windows)
            (switch-to-buffer first)
            (let ((first-window (selected-window))
                  (second-window (split-window-right)))
              (set-window-buffer second-window second)
              (setq daily-worklog--running-p t
                    daily-worklog--focused-p t)
              (cl-letf (((symbol-function 'current-time) (lambda () now))
                        ((symbol-function 'daily-worklog--resolve-project)
                         (lambda (_buffer)
                           '(:name "windows" :root "/tmp/windows"))))
                (daily-worklog--window-change (selected-frame))
                ;; A non-selected window changes, but the effective buffer does not.
                (setq now (daily-worklog-test--time-add start 5))
                (set-window-buffer second-window noise)
                (daily-worklog--window-change (selected-frame))
                (should (eq (daily-worklog--entry-buffer
                             daily-worklog--active-entry)
                            first))
                ;; Selecting an existing window is handled by the same callback.
                (set-window-buffer second-window second)
                (select-window second-window)
                (setq now (daily-worklog-test--time-add start 10))
                (daily-worklog--window-change (selected-frame))
                (setq now (daily-worklog-test--time-add start 20))
                (daily-worklog--checkpoint now nil)
                (select-window first-window)))
            (let ((summary (daily-worklog--summary-for-date
                            "2026-08-10"
                            (daily-worklog-test--time-add start 20))))
              (should (= 20 (alist-get 'totalSeconds summary)))
              (should (= 2
                         (length
                          (daily-worklog-test--buffers
                           (car (daily-worklog-test--projects summary))))))))
        (kill-buffer first)
        (kill-buffer second)
        (kill-buffer noise)))))

(ert-deftest daily-worklog-project-resolution-prefers-projectile-and-caches ()
  (daily-worklog-test--with-clean-state
    (let ((buffer (generate-new-buffer "project-worklog-test"))
          (projectile-calls 0)
          (builtin-calls 0))
      (unwind-protect
          (cl-letf (((symbol-function 'daily-worklog--projectile-info)
                     (lambda (_directory)
                       (cl-incf projectile-calls)
                       '(:name "projectile-project" :root "/tmp/projectile")))
                    ((symbol-function 'daily-worklog--builtin-project-info)
                     (lambda (_directory)
                       (cl-incf builtin-calls)
                       '(:name "builtin-project" :root "/tmp/builtin"))))
            (let ((first (daily-worklog--resolve-project buffer))
                  (second (daily-worklog--resolve-project buffer)))
              (should (equal first second))
              (should (equal "projectile-project" (plist-get first :name)))
              (should (= projectile-calls 1))
              (should (= builtin-calls 0))))
        (kill-buffer buffer)))))

(ert-deftest daily-worklog-project-resolution-falls-back-to-project-and-unassigned ()
  (daily-worklog-test--with-clean-state
    (let ((builtin-buffer (generate-new-buffer "builtin-worklog-test"))
          (unassigned-buffer (generate-new-buffer "unassigned-worklog-test")))
      (unwind-protect
          (progn
            (cl-letf (((symbol-function 'daily-worklog--projectile-info)
                       (lambda (_directory) nil))
                      ((symbol-function 'daily-worklog--builtin-project-info)
                       (lambda (_directory)
                         '(:name "builtin" :root "/tmp/builtin/"))))
              (should (equal "builtin"
                             (plist-get
                              (daily-worklog--resolve-project builtin-buffer)
                              :name))))
            (cl-letf (((symbol-function 'daily-worklog--projectile-info)
                       (lambda (_directory) nil))
                      ((symbol-function 'daily-worklog--builtin-project-info)
                       (lambda (_directory) nil)))
              (let ((project
                     (daily-worklog--resolve-project unassigned-buffer)))
                (should (equal "Unassigned" (plist-get project :name)))
                (should-not (plist-get project :root)))))
        (kill-buffer builtin-buffer)
        (kill-buffer unassigned-buffer)))))

(ert-deftest daily-worklog-save-is-atomic-and-preserves-active-interval ()
  (daily-worklog-test--with-clean-state
    (let* ((start (encode-time 0 0 10 10 8 2026))
           (now start)
           (buffer (generate-new-buffer "persistence-worklog-test")))
      (unwind-protect
          (progn
            (setq daily-worklog--running-p t
                  daily-worklog--focused-p t)
            (cl-letf (((symbol-function 'current-time) (lambda () now))
                      ((symbol-function 'daily-worklog--resolve-project)
                       (lambda (_buffer)
                         '(:name "persistence" :root "/tmp/persistence"))))
              (daily-worklog--select-buffer buffer start)
              (setq now (daily-worklog-test--time-add start 10))
              (daily-worklog-save)
              (should daily-worklog--active-entry)
              (should (equal now daily-worklog--interval-start))
              (let* ((file (daily-worklog--date-file "2026-08-10"))
                     (json (with-temp-buffer
                             (insert-file-contents file)
                             (json-parse-buffer :object-type 'alist
                                                :array-type 'list
                                                :null-object nil))))
                (should (= 10 (alist-get 'totalSeconds json)))
                (should-not
                 (directory-files daily-worklog-directory nil
                                  "\\`\\.daily-worklog-")))
              (setq now (daily-worklog-test--time-add start 20))
              (daily-worklog--checkpoint now nil)
              (should (= 20
                         (alist-get
                          'totalSeconds
                          (daily-worklog--summary-for-date
                           "2026-08-10" now))))))
        (kill-buffer buffer)))))

(ert-deftest daily-worklog-restart-loads-and-continues-current-day ()
  (daily-worklog-test--with-clean-state
    (let* ((now (encode-time 0 0 12 10 8 2026))
           (buffer (generate-new-buffer "restart-worklog-test"))
           (entry (daily-worklog-test--entry
                   buffer "restart" "/tmp/restart")))
      (unwind-protect
          (cl-letf (((symbol-function 'current-time) (lambda () now)))
            (daily-worklog--add-seconds "2026-08-10" entry 45)
            (daily-worklog-save)
            (setq daily-worklog--dates (make-hash-table :test #'equal)
                  daily-worklog--loaded-dates (make-hash-table :test #'equal)
                  daily-worklog--dirty-dates (make-hash-table :test #'equal))
            (daily-worklog--ensure-date-loaded "2026-08-10")
            (should (= 45
                       (alist-get
                        'totalSeconds
                        (daily-worklog--summary-for-date
                         "2026-08-10" now))))
            (daily-worklog--add-seconds "2026-08-10" entry 15)
            (daily-worklog-save)
            (should (= 60
                       (alist-get
                        'totalSeconds
                        (daily-worklog--read-summary "2026-08-10")))))
        (kill-buffer buffer)))))

(ert-deftest daily-worklog-midnight-spanning-interval-is-split ()
  (daily-worklog-test--with-clean-state
    (let* ((start (encode-time 0 55 23 10 8 2026))
           (end (daily-worklog-test--time-add start 600))
           (buffer (generate-new-buffer "midnight-worklog-test"))
           (entry (daily-worklog-test--entry
                   buffer "midnight" "/tmp/midnight")))
      (unwind-protect
          (progn
            (daily-worklog--accumulate entry start end)
            (should (= 300
                       (alist-get
                        'totalSeconds
                        (daily-worklog--summary-for-date
                         "2026-08-10" end))))
            (should (= 300
                       (alist-get
                        'totalSeconds
                        (daily-worklog--summary-for-date
                         "2026-08-11" end)))))
        (kill-buffer buffer)))))

(ert-deftest daily-worklog-reset-deletes-today-and-resumes ()
  (daily-worklog-test--with-clean-state
    (let* ((start (encode-time 0 0 10 10 8 2026))
           (now start)
           (buffer (generate-new-buffer "reset-worklog-test")))
      (unwind-protect
          (progn
            (setq daily-worklog--running-p t
                  daily-worklog--focused-p t)
            (cl-letf (((symbol-function 'current-time) (lambda () now))
                      ((symbol-function 'daily-worklog--resolve-project)
                       (lambda (_buffer)
                         '(:name "reset" :root "/tmp/reset"))))
              (daily-worklog--select-buffer buffer start)
              (setq now (daily-worklog-test--time-add start 30))
              (daily-worklog-save)
              (should (file-exists-p
                       (daily-worklog--date-file "2026-08-10")))
              (setq now (daily-worklog-test--time-add start 60))
              (daily-worklog-reset-today)
              (should-not (file-exists-p
                           (daily-worklog--date-file "2026-08-10")))
              (should-not (gethash "2026-08-10" daily-worklog--dates))
              (should daily-worklog--active-entry)
              (should (equal now daily-worklog--interval-start))))
        (kill-buffer buffer)))))

(ert-deftest daily-worklog-malformed-recovery-warns-and-starts-empty ()
  (daily-worklog-test--with-clean-state
    (let ((file (daily-worklog--date-file "2026-08-10"))
          warning)
      (with-temp-file file
        (insert "{not-json"))
      (cl-letf (((symbol-function 'display-warning)
                 (lambda (&rest arguments) (setq warning arguments))))
        (daily-worklog--ensure-date-loaded "2026-08-10"))
      (should warning)
      (should (gethash "2026-08-10" daily-worklog--loaded-dates))
      (should (= 0
                 (alist-get
                  'totalSeconds
                  (daily-worklog--summary-for-date
                   "2026-08-10" (encode-time 0 0 12 10 8 2026))))))))

(ert-deftest daily-worklog-mode-disable-cleans-up-completely ()
  (daily-worklog-test--with-clean-state
    (let ((post-command-before post-command-hook)
          (pre-command-before pre-command-hook)
          (buffer-list-before buffer-list-update-hook))
      (daily-worklog-mode 1)
      (should daily-worklog--running-p)
      (should (memq #'daily-worklog--window-change
                    window-buffer-change-functions))
      (should (memq #'daily-worklog--window-change
                    window-selection-change-functions))
      (with-suppressed-warnings ((obsolete focus-out-hook focus-in-hook))
        (should (memq #'daily-worklog--focus-out focus-out-hook))
        (should (memq #'daily-worklog--focus-in focus-in-hook)))
      (should (memq #'daily-worklog--kill-emacs-save kill-emacs-hook))
      (should (timerp daily-worklog--save-timer))
      (should (timerp daily-worklog--midnight-timer))
      (should (equal post-command-before post-command-hook))
      (should (equal pre-command-before pre-command-hook))
      (should (equal buffer-list-before buffer-list-update-hook))
      (daily-worklog-mode -1)
      (should-not daily-worklog--running-p)
      (should-not (memq #'daily-worklog--window-change
                        window-buffer-change-functions))
      (should-not (memq #'daily-worklog--window-change
                        window-selection-change-functions))
      (with-suppressed-warnings ((obsolete focus-out-hook focus-in-hook))
        (should-not (memq #'daily-worklog--focus-out focus-out-hook))
        (should-not (memq #'daily-worklog--focus-in focus-in-hook)))
      (should-not (memq #'daily-worklog--kill-emacs-save kill-emacs-hook))
      (should-not daily-worklog--save-timer)
      (should-not daily-worklog--midnight-timer)
      (should-not daily-worklog--active-entry)
      (should-not daily-worklog--interval-start))))

(ert-deftest daily-worklog-unassigned-root-serializes-as-json-null ()
  (daily-worklog-test--with-clean-state
    (let* ((now (encode-time 0 0 12 10 8 2026))
           (buffer (generate-new-buffer "unassigned-json-worklog-test"))
           (entry (daily-worklog-test--entry buffer "Unassigned" nil)))
      (unwind-protect
          (progn
            (daily-worklog--add-seconds "2026-08-10" entry 12)
            (let ((json
                   (json-serialize
                    (daily-worklog--summary-for-date "2026-08-10" now)
                    :null-object nil :false-object :json-false)))
              (should (string-match-p
                       "\\\"name\\\":\\\"Unassigned\\\"" json))
              (should (string-match-p "\\\"root\\\":null" json))))
        (kill-buffer buffer)))))

(ert-deftest daily-worklog-report-rounds-to-minutes-and-validates-date ()
  (daily-worklog-test--with-clean-state
    (should (equal "2m" (daily-worklog--format-duration 91)))
    (should (daily-worklog--valid-date-p "2026-08-10"))
    (should-not (daily-worklog--valid-date-p "2026-02-30"))
    (should-error (daily-worklog-show-date "2026-02-30")
                  :type 'user-error)))

(provide 'daily-worklog-test)

;;; daily-worklog-test.el ends here
