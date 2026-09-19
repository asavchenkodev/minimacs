;;; org-notes-test.el --- Tests for Org Notes  -*- lexical-binding: t; -*-

;;; Code:

(require 'ert)
(require 'org-notes)

(defvar helm-ag-base-command)

(defmacro org-notes-test--with-root (&rest body)
  "Run BODY with an isolated notes directory."
  (declare (indent 0) (debug t))
  `(let* ((root (make-temp-file "org-notes-test-" t))
          (org-notes-directory (file-name-as-directory root))
          (org-attach-id-dir (expand-file-name "attachments/" root))
          (org-agenda-files nil)
          (org-todo-keywords
           '((sequence "TODO(t)" "PROG(p/!)" "|" "DONE(d@/!)"
                       "CANCELED(c@)")))
          (org-auto-align-tags nil)
          (org-id-locations-file (expand-file-name "org-id-locations" root)))
     (unwind-protect
         (save-window-excursion ,@body)
       (dolist (buffer (buffer-list))
         (when-let ((file (buffer-file-name buffer)))
           (when (file-in-directory-p file root)
             (kill-buffer buffer))))
       (delete-directory root t))))

(defun org-notes-test--write (root relative contents)
  "Write CONTENTS under ROOT at RELATIVE and return the path."
  (let ((file (expand-file-name relative root)))
    (make-directory (file-name-directory file) t)
    (with-temp-file file (insert contents))
    file))

(ert-deftest org-notes-iso-week-file-handles-year-boundaries ()
  (org-notes-test--with-root
    (should (string-suffix-p
             "/weekly/2026-W01.org"
             (org-notes-weekly-file (encode-time 0 0 12 29 12 2025))))
    (should (string-suffix-p
             "/weekly/2026-W53.org"
             (org-notes-weekly-file (encode-time 0 0 12 31 12 2026))))))

(ert-deftest org-notes-files-are-recursive-and-exclude-private-storage ()
  (org-notes-test--with-root
    (let ((first (org-notes-test--write root "weekly/2026-W38.org" "* A\n"))
          (second (org-notes-test--write root "projects/home.org" "* B\n")))
      (org-notes-test--write root "attachments/aa/file.org" "ignored")
      (org-notes-test--write root ".git/private.org" "ignored")
      (should (equal (sort (org-notes-files) #'string-lessp)
                     (sort (list first second) #'string-lessp))))))

(ert-deftest org-notes-search-passes-ripgrep-globs-without-literal-quotes ()
  (org-notes-test--with-root
    (org-notes-test--write root "weekly/week.org" "* Searchable text\n")
    (let ((original-require (symbol-function 'require))
          (helm-ag-base-command "rg --color=always")
          command basedir)
      (cl-letf (((symbol-function 'require)
                 (lambda (feature &rest arguments)
                   (if (eq feature 'helm-ag)
                       t
                     (apply original-require feature arguments))))
                ((symbol-function 'helm-do-ag)
                 (lambda (directory _targets _query)
                   (setq basedir directory command helm-ag-base-command))))
        (org-notes-search))
      (should (equal basedir (file-name-as-directory root)))
      (should (string-match-p "--glob=\\*\\.org" command))
      (should-not (string-match-p "'\\*\\.org'" command)))))

(ert-deftest org-notes-find-file-offers-weekly-and-standalone-files ()
  (org-notes-test--with-root
    (let ((weekly (org-notes-test--write root "weekly/week.org" "* Week\n"))
          (note (org-notes-test--write root "notes/note.org" "* Note\n"))
          (original-require (symbol-function 'require))
          candidates opened)
      (cl-letf (((symbol-function 'require)
                 (lambda (feature &rest arguments)
                   (if (eq feature 'helm)
                       t
                     (apply original-require feature arguments))))
                ((symbol-function 'helm-comp-read)
                 (lambda (_prompt collection &rest _arguments)
                   (setq candidates collection)
                   note))
                ((symbol-function 'find-file)
                 (lambda (file &rest _arguments) (setq opened file))))
        (org-notes-find-file))
      (should (equal opened note))
      (should (equal (sort (mapcar #'cdr candidates) #'string-lessp)
                     (sort (list weekly note) #'string-lessp))))))

(ert-deftest org-notes-capture-target-creates-week-and-day-heading ()
  (org-notes-test--with-root
    (let ((now (encode-time 0 30 10 18 9 2026)))
      (cl-letf (((symbol-function 'current-time) (lambda () now)))
        (org-notes--capture-target)
        (should (equal (buffer-file-name) (org-notes-weekly-file now)))
        (should (org-at-heading-p))
        (should (equal (org-get-heading t t t t)
                       "2026-09-18 Friday"))
        (should (string-match-p
                 "#\\+title: Week 2026-W38"
                 (buffer-string)))))))

(ert-deftest org-notes-capture-templates-use-type-project-and-clear-dates ()
  (org-notes-test--with-root
    (cl-letf (((symbol-function 'org-notes--read-project-tag)
               (lambda () "project_emacs_config")))
      (let ((task (org-notes--task-template))
            (event (org-notes--event-template))
            (habit (org-notes--habit-template)))
        (should (string-prefix-p
                 "* TODO %? :task:project_emacs_config:" task))
        (should (string-match-p "Captured: %U" task))
        (should (string-match-p "Occurs: %T" event))
        (should (string-match-p ":STYLE: habit" habit))
        (should (string-match-p "\\.\\+1d" habit))))))

(ert-deftest org-notes-project-completion-comes-from-project-tags ()
  (org-notes-test--with-root
    (org-notes-test--write
     root "one.org"
     "* Note :note:project_alpha:\n* Other :topic:project_beta:\n")
    (should (equal '("project_alpha" "project_beta")
                   (org-notes--project-tags)))))

(ert-deftest org-notes-canceled-capture-does-not-leave-entry ()
  (org-notes-test--with-root
    (org-notes-setup)
    (cl-letf (((symbol-function 'org-notes--read-project-tag)
               (lambda () nil)))
      (let ((org-notes--capture-active nil))
        (org-capture nil "t")
        (insert "Canceled text")
        (org-capture-kill)))
    (dolist (file (org-notes-files))
      (with-temp-buffer
        (insert-file-contents file)
        (should-not (search-forward "Canceled text" nil t))))))

(ert-deftest org-notes-note-capture-creates-standalone-file ()
  (org-notes-test--with-root
    (org-notes-setup)
    (cl-letf (((symbol-function 'read-string)
               (lambda (&rest _arguments) "Car notes"))
              ((symbol-function 'org-notes--read-project-tag)
               (lambda () "project_mobis")))
      (let ((org-notes--capture-active nil))
        (org-capture nil "n")
        (insert "Standalone description")
        (org-capture-finalize)))
    (let* ((files (org-notes-files))
           (file (car files)))
      (should (= 1 (length files)))
      (should (string-match-p
               "/notes/[0-9-]+--car-notes\\.org\\'" file))
      (with-temp-buffer
        (insert-file-contents file)
        (should (string-match-p "#\\+title: Car notes" (buffer-string)))
        (should (string-match-p
                 "^\\* Car notes.*:note:project_mobis:" (buffer-string)))
        (should (string-match-p "Standalone description" (buffer-string)))))))

(ert-deftest org-notes-task-capture-starts-title-before-tags ()
  (org-notes-test--with-root
    (org-notes-setup)
    (cl-letf (((symbol-function 'org-notes--read-project-tag)
               (lambda () "project_mobis")))
      (let ((org-notes--capture-active nil))
        (org-capture nil "t")
        (insert "Prepare report")
        (org-capture-finalize)))
    (with-temp-buffer
      (insert-file-contents (car (org-notes-files)))
      (should (re-search-forward
               "^\\*\\* TODO Prepare report +:task:project_mobis:" nil t)))))

(ert-deftest org-notes-successful-habit-capture-expands-native-metadata ()
  (org-notes-test--with-root
    (org-notes-setup)
    (cl-letf (((symbol-function 'org-notes--read-project-tag)
               (lambda () "project_health")))
      (let ((org-notes--capture-active nil))
        (org-capture nil "h")
        (insert "Walk")
        (org-capture-finalize)))
    (let ((file (expand-file-name "habits.org" root)))
      (should (equal (org-notes-files) (list file)))
      (with-temp-buffer
        (insert-file-contents file)
        (should (re-search-forward "^#\\+title: Habits$" nil t))
        (should (re-search-forward
                 "^\\* TODO Walk.*:habit:project_health:" nil t))
        (should (re-search-forward "^SCHEDULED: <.* \\.\\+1d>" nil t))
        (should (re-search-forward "^:STYLE: habit$" nil t))
        (should (re-search-forward "^:LOGGING: logrepeat$" nil t))
        (should (re-search-forward "^Captured: \\[.*[0-9][0-9]:[0-9][0-9]\\]$"
                                   nil t))))))

(ert-deftest org-notes-habit-captures-remain-top-level-in-one-file ()
  (org-notes-test--with-root
    (org-notes-setup)
    (cl-letf (((symbol-function 'org-notes--read-project-tag)
               (lambda () nil)))
      (dolist (title '("Walk" "Read"))
        (let ((org-notes--capture-active nil))
          (org-capture nil "h")
          (insert title)
          (org-capture-finalize))))
    (let ((file (expand-file-name "habits.org" root)))
      (with-temp-buffer
        (insert-file-contents file)
        (should (re-search-forward "^\\* TODO Walk :habit:" nil t))
        (should (re-search-forward "^\\* TODO Read :habit:" nil t))
        (should-not (re-search-forward "^\\*\\* TODO" nil t))))))

(ert-deftest org-notes-habit-completion-uses-native-repeat-log-without-note ()
  (org-notes-test--with-root
    (let ((file (org-notes-test--write
                 root "weekly/habits.org"
                 (format (concat "* TODO Walk :habit:\n"
                                 "SCHEDULED: <%s .+1d>\n"
                                 ":PROPERTIES:\n:STYLE: habit\n"
                                 ":LOGGING: logrepeat\n:END:\n")
                         (format-time-string "%Y-%m-%d %a")))))
      (with-current-buffer (find-file-noselect file)
        (goto-char (point-min))
        (let ((org-log-repeat 'time)
              (org-log-into-drawer t))
          (org-todo "DONE")
          (should (equal "TODO" (org-get-todo-state)))
          (should (eq 'state org-log-note-how))
          (org-add-log-note)
          (should (string-match-p "State \"DONE\" +from \"TODO\""
                                  (buffer-string))))))))

(ert-deftest org-notes-task-comparator-sorts-deadlines-projects-and-tags ()
  (org-notes-test--with-root
    (let* ((file (org-notes-test--write
                  root "tasks.org"
                  (concat "* TODO Late :task:project_zulu:misc:\n"
                          "DEADLINE: <2026-09-20 Sun>\n"
                          "* TODO Early :task:project_alpha:urgent:\n"
                          "DEADLINE: <2026-09-19 Sat>\n")))
           (buffer (find-file-noselect file))
           first second)
      (with-current-buffer buffer
        (goto-char (point-min))
        (setq first (propertize "Late" 'org-marker (point-marker)))
        (re-search-forward "^\\* TODO Early")
        (setq second (propertize "Early" 'org-marker
                                (copy-marker (line-beginning-position)))))
      (let ((org-notes--task-sort-mode 'deadline))
        (should (= 1 (org-notes--task-agenda-compare first second))))
      (let ((org-notes--task-sort-mode 'project))
        (should (= 1 (org-notes--task-agenda-compare first second))))
      (let ((org-notes--task-sort-mode 'tag))
        (should (= -1 (org-notes--task-agenda-compare first second)))))))

(ert-deftest org-notes-attachment-copies-file-and-link-survives-reopen ()
  (org-notes-test--with-root
    (let* ((source (org-notes-test--write root "source.txt" "contents"))
           (note (org-notes-test--write root "weekly/note.org" "* Note\n")))
      (with-current-buffer (find-file-noselect note)
        (goto-char (point-min))
        (org-notes-attach-file source)
        (should (string-match-p
                 "\\[\\[attachment:source.txt\\]\\[source.txt\\]\\]"
                 (buffer-string)))
        (let ((attachment (org-attach-expand "source.txt")))
          (should (file-exists-p attachment))
          (should (file-exists-p source)))
        (save-buffer)
        (kill-buffer (current-buffer)))
      (with-current-buffer (find-file-noselect note)
        (should (string-match-p "attachment:source.txt" (buffer-string)))
        (goto-char (point-min))
        (should (file-exists-p (org-attach-expand "source.txt")))))))

(ert-deftest org-notes-paste-image-uses-native-yank-media-attachment ()
  (org-notes-test--with-root
    (let ((note (org-notes-test--write root "note.org" "* Screenshot\n"))
          called method)
      (with-current-buffer (find-file-noselect note)
        (goto-char (point-min))
        (cl-letf (((symbol-function 'yank-media)
                   (lambda ()
                     (interactive)
                     (setq called t method org-yank-image-save-method))))
          (org-notes-paste-image))
        (should called)
        (should (eq method 'attach))))))

(ert-deftest org-notes-activity-finalizer-is-idempotent ()
  (org-notes-test--with-root
    (with-temp-buffer
      (org-agenda-mode)
      (let ((inhibit-read-only t))
        (insert (propertize "Friday 18 September\n"
                            'org-date-line t 'day
                            (calendar-absolute-from-gregorian '(9 18 2026)))))
      (cl-letf (((symbol-function 'daily-worklog-summary-for-date)
                 (lambda (_date) nil)))
        (org-notes--insert-worklog-rows)
        (org-notes--insert-worklog-rows))
      (goto-char (point-min))
      (should (= 1 (how-many "Worklog:" (point-min) (point-max)))))))

(ert-deftest org-notes-task-and-habit-agendas-separate-lifecycles ()
  (org-notes-test--with-root
    (let ((today (format-time-string "%Y-%m-%d %a")))
      (org-notes-test--write
       root "weekly/current.org"
       (format (concat "* TODO Open task :task:project_alpha:\n"
                       "DEADLINE: <%s>\n"
                       "* PROG Active task :task:\n"
                       "* TODO Habit entry :habit:\n"
                       "SCHEDULED: <%s .+1d>\n"
                       ":PROPERTIES:\n:STYLE: habit\n:END:\n")
               today today)))
    (org-notes-setup)
    (org-notes-tasks)
    (with-current-buffer "*Org Agenda*"
      (should (string-match-p "Open task" (buffer-string)))
      (should (string-match-p "Active task" (buffer-string)))
      (should-not (string-match-p "Habit entry" (buffer-string))))
    (org-notes-habits)
    (with-current-buffer "*Org Agenda*"
      (should (string-match-p "Habit entry" (buffer-string)))
      (should-not (string-match-p "Open task" (buffer-string))))))

(ert-deftest org-notes-habit-classification-uses-style-and-open-todo ()
  (org-notes-test--with-root
    (let ((today (format-time-string "%Y-%m-%d %a")))
      (org-notes-test--write
       root "weekly/current.org"
       (format (concat "* TODO Styled habit :habit:\n"
                       "SCHEDULED: <%s .+1d>\n"
                       ":PROPERTIES:\n:STYLE: habit\n:END:\n"
                       "* TODO Tagged ordinary task :habit:\n"
                       "* DONE Finished habit :habit:\n"
                       "SCHEDULED: <%s .+1d>\n"
                       ":PROPERTIES:\n:STYLE: habit\n:END:\n")
               today today)))
    (org-notes-setup)
    (org-notes-tasks)
    (with-current-buffer "*Org Agenda*"
      (should (string-match-p "Tagged ordinary task" (buffer-string)))
      (should-not (string-match-p "Styled habit" (buffer-string))))
    (org-notes-habits)
    (with-current-buffer "*Org Agenda*"
      (should (string-match-p "Styled habit" (buffer-string)))
      (should-not (string-match-p "Tagged ordinary task" (buffer-string)))
      (should-not (string-match-p "Finished habit" (buffer-string))))))

(ert-deftest org-notes-dashboard-combines-habits-dates-and-open-tasks ()
  (org-notes-test--with-root
    (let* ((today (format-time-string "%Y-%m-%d %a"))
           (tomorrow (format-time-string
                      "%Y-%m-%d %a" (time-add nil (days-to-time 1)))))
      (org-notes-test--write
       root "habits.org"
       (format (concat "#+title: Habits\n\n"
                       "* TODO Daily walk :habit:\n"
                       "SCHEDULED: <%s .+1d>\n"
                       ":PROPERTIES:\n:STYLE: habit\n:END:\n")
               today))
      (org-notes-test--write
       root "weekly/current.org"
       (format (concat "* TODO Submit report :task:\n"
                       "DEADLINE: <%s>\n"
                       "* Event :event:\nOccurs: <%s>\n"
                       "* DONE Finished task :task:\n")
               tomorrow tomorrow))
      (org-notes-test--write root "weekly/old.org"
                             "* TODO Older open task :task:\n"))
    (org-notes-setup)
    (org-notes-dashboard)
    (with-current-buffer "*Org Agenda*"
      (let ((view (buffer-substring-no-properties (point-min) (point-max))))
        (should (eq 'dashboard org-notes--agenda-kind))
        (should (string-match-p "Habits today" view))
        (should (string-match-p "Next 7 days" view))
        (should (string-match-p "Open tasks" view))
        (should (string-match-p "Daily walk" view))
        (should (= 1 (how-many "Daily walk" (point-min) (point-max))))
        (should (string-match-p "Submit report" view))
        (should (string-match-p "Older open task" view))
        (should (string-match-p "Event" view))
        (should-not (string-match-p "Finished task" view)))
      (goto-char (point-min))
      (search-forward "Older open task")
      (org-notes-agenda-open)
      (should (equal "Older open task" (org-get-heading t t t t))))))

(ert-deftest org-notes-dashboard-refresh-discovers-new-files ()
  (org-notes-test--with-root
    (org-notes-test--write root "weekly/current.org"
                           "* TODO Existing task :task:\n")
    (org-notes-setup)
    (org-notes-dashboard)
    (org-notes-test--write root "notes/new.org"
                           "* TODO Newly added task :task:\n")
    (with-current-buffer "*Org Agenda*"
      (org-notes-agenda-redo)
      (should (eq 'dashboard org-notes--agenda-kind))
      (should (string-match-p "Newly added task" (buffer-string))))))

(ert-deftest org-notes-agenda-opens-in-right-hand-split ()
  (org-notes-test--with-root
    (org-notes-test--write root "weekly/current.org" "* TODO Side by side :task:\n")
    (org-notes-setup)
    (delete-other-windows)
    (switch-to-buffer (get-buffer-create "org-notes-left-test"))
    (org-notes-tasks)
    (let ((windows (window-list nil 'no-minibuffer)))
      (should (= 2 (length windows)))
      (should (eq (window-buffer (selected-window)) (get-buffer "*Org Agenda*")))
      (should (> (car (window-edges (selected-window))) 0))
      (should (= (cadr (window-edges (selected-window)))
                 (cadr (window-edges (car (delq (selected-window)
                                                (copy-sequence windows))))))))))

(ert-deftest org-notes-weekly-agenda-moves-by-full-weeks ()
  (org-notes-test--with-root
    (org-notes-test--write root "weekly/current.org" "* A note :note:\n")
    (org-notes-setup)
    (cl-letf (((symbol-function 'daily-worklog-summary-for-date)
               (lambda (_date) nil)))
      (org-notes-weekly-activity)
      (should (eq (lookup-key org-agenda-mode-map (kbd "C-c ["))
                  'org-agenda-earlier))
      (should (eq (lookup-key org-agenda-mode-map (kbd "C-c ]"))
                  'org-agenda-later))
      (let ((start org-starting-day))
        (org-agenda-later 1)
        (should (= (+ start 7) org-starting-day))
        (org-agenda-earlier 1)
        (should (= start org-starting-day))))))

(ert-deftest org-notes-weekly-agenda-labels-history-and-worklog ()
  (org-notes-test--with-root
    (let* ((captured (format-time-string "%Y-%m-%d %a 10:00"))
           (occurred (format-time-string
                      "%Y-%m-%d %a 11:00" (time-add nil (days-to-time 1))))
           (file (org-notes-weekly-file)))
      (org-notes-test--write
       root (file-relative-name file root)
       (format (concat "* Day\n"
                       "** Note entry :note:\nCaptured: [%s]\n"
                       "Occurs: <%s>\n"
                       "** DONE Done task :task:\nCLOSED: [%s]\n")
               captured occurred captured)))
    (org-notes-setup)
    (cl-letf (((symbol-function 'daily-worklog-summary-for-date)
               (lambda (_date) nil)))
      (org-notes-weekly-activity))
    (with-current-buffer "*Org Agenda*"
      (should (string-match-p "Captured: +Note entry" (buffer-string)))
      (should (string-match-p "Occurs: +Note entry" (buffer-string)))
      (should (= 1 (how-many "Closed: +DONE Done task"
                             (point-min) (point-max))))
      (should (= 7 (how-many "Worklog: No recorded activity"
                             (point-min) (point-max)))))))

(ert-deftest org-notes-weekly-agenda-labels-repeated-habit-completion ()
  (org-notes-test--with-root
    (let* ((today (format-time-string "%Y-%m-%d %a 12:00"))
           (tomorrow (format-time-string
                      "%Y-%m-%d %a" (time-add nil (days-to-time 1)))))
      (org-notes-test--write
       root "weekly/current.org"
       (format (concat "* TODO Walk :habit:\n"
                       "SCHEDULED: <%s .+1d>\n"
                       ":PROPERTIES:\n:STYLE: habit\n:END:\n"
                       ":LOGBOOK:\n"
                       "- State \"DONE\"       from \"TODO\"       [%s]\n"
                       ":END:\n")
               tomorrow today)))
    (org-notes-setup)
    (cl-letf (((symbol-function 'daily-worklog-summary-for-date)
               (lambda (_date) nil)))
      (org-notes-weekly-activity))
    (with-current-buffer "*Org Agenda*"
      (let ((view (buffer-substring-no-properties (point-min) (point-max))))
        (should (string-match-p "Completed:.*Walk" view))
        (should (= 1 (how-many "Completed:" (point-min) (point-max))))))))

(provide 'org-notes-test)
;;; org-notes-test.el ends here
