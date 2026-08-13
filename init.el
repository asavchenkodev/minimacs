;;; init.el --- Small standalone Emacs configuration -*- lexical-binding: t; -*-

;; Start this profile without touching Spacemacs:
;; /Applications/Emacs.app/Contents/MacOS/Emacs \
;;   --init-directory=/Users/asv/projects/emacs-config

;;; Profile-local state

(require 'package)
(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(declare-function company-complete-common-or-cycle "company")
(declare-function company-complete-selection "company")
(declare-function company-select-next "company")
(declare-function company-select-previous "company")
(declare-function clang-format "clang-format")
(declare-function clang-format-buffer "clang-format")
(declare-function clang-format-region "clang-format")
(declare-function c-defun-name "cc-cmds")
(declare-function c-mark-function "cc-cmds")
(declare-function dired-find-alternate-file "dired")
(declare-function dired-hide-details-mode "dired")
(declare-function dired-up-directory "dired")
(declare-function etags-regen--tags-cleanup "etags-regen")
(declare-function etags-regen--tags-generate "etags-regen")
(declare-function evil-iedit-state/iedit-mode "evil-iedit-state")
(declare-function evil-define-key* "evil-core")
(declare-function flyspell-goto-next-error "flyspell")
(declare-function flymake-mode "flymake")
(declare-function helm-autoresize-mode "helm")
(declare-function helm-find-files-1 "helm-files")
(declare-function helm-find-files-down-last-level "helm-files")
(declare-function helm-find-files-up-one-level "helm-files")
(declare-function helm-do-ag "helm-ag")
(declare-function helm-do-ag-project-root "helm-ag")
(declare-function helm-do-ag-this-file "helm-ag")
(declare-function helm-ag-mode-jump-other-window "helm-ag")
(declare-function helm-ag--do-ag-up-one-level "helm-ag")
(declare-function helm-ag--up-one-level "helm-ag")
(declare-function helm-execute-persistent-action "helm")
(declare-function helm-beginning-of-source-p "helm-core")
(declare-function helm-end-of-source-p "helm-core")
(declare-function helm-keyboard-quit "helm")
(declare-function helm-next-line "helm")
(declare-function helm-next-page "helm")
(declare-function helm-next-source "helm")
(declare-function helm-previous-page "helm")
(declare-function helm-previous-line "helm")
(declare-function helm-previous-source "helm")
(declare-function helm-resume "helm")
(declare-function helm-run-after-exit "helm")
(declare-function helm-select-action "helm")
(declare-function helm-set-attr "helm-core")
(declare-function helm-set-local-variable "helm")
(declare-function helm-window "helm-core")
(declare-function justl--parse "justl")
(declare-function justl--pop-to-buffer "justl")
(declare-function justl--get-recipe-under-cursor "justl")
(declare-function justl--read-arg "justl")
(declare-function justl--recipe-args "justl")
(declare-function justl--recipe-desc "justl")
(declare-function justl--recipe-name "justl")
(declare-function justl-mode "justl")
(declare-function make-recipe "justl" (&rest arguments))
(declare-function kill-compilation "compile")
(declare-function projectile-switch-project-by-name "projectile")
(declare-function projectile-save-known-projects "projectile")
(declare-function recompile "compile")
(declare-function tags-reset-tags-tables "etags")

(defvar helm-ag--default-target)
(defvar helm-ag--search-this-file-p)
(defvar helm-ag-always-set-extra-option)
(defvar helm-ag-source)
(defvar helm-buffer)
(defvar helm-input)
(defvar helm-move-to-line-cycle-in-source)
(defvar helm-source-do-ag)
(defvar helm-white-buffer-regexp-list)
(defvar evil-iedit-state-map)
(defvar justl--last-justl-buffer)
(defvar justl-compile-mode-map)
(defvar justl-executable)
(defvar justl-include-private-recipes)
(defvar justl-justfile)
(defvar justl-mode-map)
(defvar ispell-program-name nil)
(defvar xref--xref-buffer-mode-map)
(defvar org-persist--disable-when-emacs-Q)
(defvar projectile-known-projects)
(defvar treemacs-last-error-persist-file)
(defvar treemacs-persist-file)

(defconst my/var-directory (expand-file-name "var/" user-emacs-directory))
(defconst my/backup-directory (expand-file-name "backups/" my/var-directory))
(defconst my/autosave-directory (expand-file-name "auto-save/" my/var-directory))
(defconst my/tags-directory (expand-file-name "tags/" my/var-directory))

(defconst my/helm-ag-rg-options-with-values
  '("--after-context" "--before-context" "--context"
    "--context-separator" "--dfa-size-limit" "--encoding" "--engine"
    "--glob" "--iglob" "--ignore-file" "--max-columns" "--max-count"
    "--max-depth" "--max-filesize" "--path-separator" "--pre"
    "--pre-glob" "--regexp" "--replace" "--sort" "--sortr" "--threads"
    "--type" "--type-add" "--type-clear" "--type-not"
    "-A" "-B" "-C" "-E" "-f" "-g" "-M" "-m" "-r" "-t" "-T" "-e")
  "Ripgrep options whose following token is an option value, not query text.")

(dolist (directory (list my/var-directory
                         my/backup-directory
                         my/autosave-directory
                         my/tags-directory))
  (make-directory directory t))

(setq package-user-dir (expand-file-name "elpa/" user-emacs-directory)
      custom-file (expand-file-name "custom.el" my/var-directory)
      savehist-file (expand-file-name "savehist.el" my/var-directory)
      recentf-save-file (expand-file-name "recentf.el" my/var-directory)
      bookmark-default-file (expand-file-name "bookmarks.el" my/var-directory)
      project-list-file (expand-file-name "projects.el" my/var-directory)
      url-history-file (expand-file-name "url-history.el" my/var-directory)
      transient-history-file (expand-file-name "transient-history.el" my/var-directory)
      transient-levels-file (expand-file-name "transient-levels.el" my/var-directory)
      transient-values-file (expand-file-name "transient-values.el" my/var-directory)
      org-persist-directory (expand-file-name "org-persist/" my/var-directory)
      org-persist--disable-when-emacs-Q nil
      auto-save-list-file-prefix (expand-file-name ".saves-" my/autosave-directory)
      backup-directory-alist `(("." . ,my/backup-directory))
      auto-save-file-name-transforms `((".*" ,my/autosave-directory t)))

(defun my/file-sha256 (file)
  "Return the SHA-256 digest of FILE's literal bytes."
  (with-temp-buffer
    (set-buffer-multibyte nil)
    (insert-file-contents-literally file)
    (secure-hash 'sha256 (current-buffer))))

(defun my/delete-redundant-auto-save (&rest _)
  "Delete a newer auto-save only when it exactly matches the visited file."
  (when buffer-file-name
    (condition-case nil
        (let ((auto-save (or buffer-auto-save-file-name
                             (make-auto-save-file-name))))
          (when (and (file-regular-p buffer-file-name)
                     (file-regular-p auto-save)
                     (file-newer-than-file-p auto-save buffer-file-name)
                     (= (file-attribute-size (file-attributes auto-save))
                        (file-attribute-size (file-attributes buffer-file-name)))
                     (string= (my/file-sha256 auto-save)
                              (my/file-sha256 buffer-file-name)))
            (delete-file auto-save)))
      (file-error nil))))

;; `after-find-file' otherwise displays a recovery warning and deliberately
;; pauses for one second, even when the auto-save is identical to the file.
(advice-add 'after-find-file :before #'my/delete-redundant-auto-save)

;;; Package bootstrap

(setq evil-want-integration t
      evil-want-keybinding nil
      evil-want-C-u-scroll t
      evil-want-Y-yank-to-eol nil
      evil-kill-on-visual-paste nil
      evil-undo-system 'undo-redo)

(setq package-archives
      '(("gnu" . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")
        ("melpa" . "https://melpa.org/packages/")))

;; This is needed in batch tests and is harmless during normal startup, where
;; package activation has already happened before init.el is loaded.
(package-initialize)

(defconst my/archive-packages
  '(ace-window
    clang-format
    company
    dashboard
    doom-modeline
    drag-stuff
    evil
    evil-collection
    expand-region
    flyspell-correct
    flyspell-correct-helm
    helm
    helm-projectile
    iedit
    just-mode
    justl
    magit
    nerd-icons
    planet-theme
    projectile
    shell-pop
    treemacs-icons-dired
    vterm
    winum)
  "Packages installed from GNU ELPA, NonGNU ELPA, or MELPA.")

(defun my/install-missing-packages ()
  "Install missing packages, refreshing archives only when necessary."
  (let ((missing (seq-remove #'package-installed-p my/archive-packages)))
    (when missing
      ;; A saved archive index can refer to MELPA snapshots that have already
      ;; rotated out.  Refresh only on a genuinely missing-package bootstrap.
      (package-refresh-contents)
      (dolist (package missing)
        (package-install package)))))

(my/install-missing-packages)

;; helm-ag was removed from MELPA.  This is the same fork and revision used by
;; the existing Spacemacs installation, installed only inside this profile.
(unless (package-installed-p 'helm-ag)
  (require 'package-vc)
  (package-vc-install
   "https://github.com/smile13241324/helm-ag.git"
   "8d61b22ad5b0fdc2715779bae0312305499bb643"
   'Git
   'helm-ag))

;; Use the same Evil Iedit revision as the existing Spacemacs profile.  It is
;; kept profile-local and only downloaded during a missing-package bootstrap.
(unless (package-installed-p 'evil-iedit-state)
  (require 'package-vc)
  (package-vc-install
   "https://github.com/smile13241324/evil-iedit-state.git"
   "a44bc05acb49708aba124129d0e941084e8e14b6"
   'Git
   'evil-iedit-state))

(require 'use-package)
(setq use-package-always-ensure nil)

;;; Platform environment and basic UI

(defun my/prepend-executable-directory (directory)
  "Prepend existing DIRECTORY to both `exec-path' and PATH."
  (when (file-directory-p directory)
    (add-to-list 'exec-path directory)
    (let ((path (or (getenv "PATH") "")))
      (unless (member directory (split-string path path-separator t))
        (setenv "PATH" (if (string-empty-p path)
                           directory
                         (concat directory path-separator path)))))))

;; GUI applications do not always inherit the login shell's complete PATH.
;; Add only directories belonging to the current operating system.
(pcase system-type
  ('darwin
   (my/prepend-executable-directory "/usr/local/bin")
   (my/prepend-executable-directory "/opt/homebrew/bin"))
  ('gnu/linux
   (my/prepend-executable-directory "/usr/bin")
   (my/prepend-executable-directory "/usr/local/bin")))

(defun my/find-executable (program &rest fallback-files)
  "Find PROGRAM on PATH or in executable FALLBACK-FILES."
  (or (executable-find program)
      (seq-find #'file-executable-p (delq nil fallback-files))))

(defun my/etags-executable ()
  "Return the platform-appropriate GNU Etags executable, if available."
  (apply #'my/find-executable
         "etags"
         (pcase system-type
           ('darwin '("/opt/homebrew/bin/etags"))
           ('gnu/linux '("/usr/local/bin/etags" "/usr/bin/etags"))
           (_ nil))))

(defun my/spell-checker-executable ()
  "Return the preferred spelling executable for this platform."
  (pcase system-type
    ('darwin
     (or (my/find-executable "hunspell" "/opt/homebrew/bin/hunspell")
         (my/find-executable "aspell")))
    ('gnu/linux
     (or (my/find-executable "aspell" "/usr/bin/aspell")
         (my/find-executable "hunspell")))
    (_
     (or (my/find-executable "aspell")
         (my/find-executable "hunspell")
         (my/find-executable "ispell")))))

(defun my/python-executable ()
  "Return the preferred Python executable for this platform."
  (or (my/find-executable
       "python3"
       (pcase system-type
         ('darwin "/opt/homebrew/bin/python3")
         ('gnu/linux "/usr/bin/python3")))
      (my/find-executable "python")))

(defvar my/python-program nil
  "Python executable shared by Python mode and Org Babel.")

(setq my/python-program
      (or (my/python-executable)
          "python3"))

(add-to-list 'default-frame-alist '(fullscreen . fullboth))
(when (eq system-type 'darwin)
  (add-to-list 'default-frame-alist '(font . "Menlo-12")))
(add-to-list 'initial-frame-alist '(fullscreen . fullboth))

(when (fboundp 'tool-bar-mode)
  (tool-bar-mode -1))
(when (fboundp 'scroll-bar-mode)
  (scroll-bar-mode -1))

(column-number-mode 1)
(setq display-line-numbers-type 'relative
      history-delete-duplicates t
      history-length 1000
      inhibit-startup-screen t
      initial-scratch-message nil
      ring-bell-function #'ignore
      custom-safe-themes t)

(add-hook 'prog-mode-hook #'display-line-numbers-mode)
(add-hook 'text-mode-hook #'display-line-numbers-mode)

;; Keep the Helm M-x most-recently-used section across Emacs restarts.
(setq savehist-additional-variables '(extended-command-history))
(savehist-mode 1)
(recentf-mode 1)

(use-package planet-theme
  :demand t
  :config
  (load-theme 'planet t))

;; A compact mode line with the useful context kept visible and minor-mode
;; noise removed.  Keep this text-first so it renders consistently on macOS,
;; Ubuntu, and terminals without depending on Nerd Fonts.
(use-package doom-modeline
  :demand t
  :init
  (setq doom-modeline-height 26
        doom-modeline-bar-width 3
        doom-modeline-hud nil
        doom-modeline-window-width-limit 50
        doom-modeline-buffer-file-name-style 'file-name
        doom-modeline-buffer-name t
        doom-modeline-highlight-modified-buffer-name t
        doom-modeline-icon nil
        doom-modeline-major-mode-icon nil
        doom-modeline-major-mode-color-icon nil
        doom-modeline-buffer-state-icon nil
        doom-modeline-buffer-modification-icon nil
        doom-modeline-unicode-number nil
        doom-modeline-unicode-fallback nil
        doom-modeline-minor-modes nil
        doom-modeline-selection-info t
        doom-modeline-buffer-encoding nil
        doom-modeline-indent-info nil
        doom-modeline-check nil
        doom-modeline-project-name t
        doom-modeline-workspace-name nil
        doom-modeline-persp-name nil
        doom-modeline-lsp nil
        doom-modeline-env-version nil
        doom-modeline-modal nil
        doom-modeline-modal-icon nil
        doom-modeline-modal-modern-icon nil
        doom-modeline-vcs-max-length 18)
  :config
  ;; The matches segment also renders the red record-dot/triangle while a
  ;; keyboard macro is active.  The modeline is intentionally minimal, so do
  ;; not show that transient icon group either.
  (doom-modeline-remove-segment 'matches)
  (doom-modeline-mode 1))

;;; Editing defaults

(setq-default indent-tabs-mode nil
              show-trailing-whitespace t)

(setq split-height-threshold nil
      split-width-threshold 300
      compile-command ""
      compilation-scroll-output t
      compilation-skip-threshold 2
      dired-listing-switches "-alh"
      dired-dwim-target t
      dired-use-ls-dired nil
      dired-kill-when-opening-new-dired-buffer t)

(setq c-default-style '((java-mode . "java")
                        (awk-mode . "awk")
                        (other . "stroustrup")))

(put 'dired-find-alternate-file 'disabled nil)
(with-eval-after-load 'dired
  (require 'dired-x))

;;; Small commands used by the leader map

(defun my/alternate-buffer ()
  "Switch back and forth between the current and last buffer."
  (interactive)
  ;; Match Spacemacs: clearing the forward list on both sides makes repeated
  ;; SPC TAB presses toggle reliably between exactly two buffers.
  (set-window-next-buffers nil nil)
  (previous-buffer)
  (set-window-next-buffers nil nil))

(defun my/find-justfile (&optional directory)
  "Find the nearest Justfile above DIRECTORY or `default-directory'."
  (let* ((start (file-name-as-directory
                 (expand-file-name (or directory default-directory))))
         (names '("justfile" "Justfile" ".justfile"))
         (root (locate-dominating-file
                start
                (lambda (candidate)
                  (seq-some
                   (lambda (name)
                     (file-regular-p (expand-file-name name candidate)))
                   names)))))
    (when root
      (seq-find #'file-regular-p
                (mapcar (lambda (name) (expand-file-name name root)) names)))))

(defun my/just-choose-recipe ()
  "Open a recipe chooser for the nearest Justfile.

The selected recipe runs in a compilation-derived buffer.  If the chooser
cannot parse the Justfile, fall back to compiling the default `just' recipe
from the directory containing that file."
  (interactive)
  (unless (executable-find "just")
    (user-error "Cannot find `just' on PATH"))
  (let ((justfile (my/find-justfile)))
    (unless justfile
      (user-error "No Justfile found above %s"
                  (abbreviate-file-name default-directory)))
    (condition-case error-data
        (progn
          (require 'justl)
          (my/justl-open justfile))
      (error
       (message "Just recipe chooser failed (%s); running default recipe"
                (error-message-string error-data))
       (let ((default-directory (file-name-directory justfile))
             (compilation-buffer-name-function (lambda (_) "*just*")))
         (compile "just"))))))

(defun my/justl-recipes-with-modules (justfile)
  "Return recipes from JUSTFILE and every nested Just module.

Each result is (RECIPE SOURCE LOCAL-NAME).  RECIPE uses Just's qualified
`module::recipe' name so Justl can execute it from the root JUSTFILE."
  (let ((parsed (justl--parse justfile))
        rows)
    (cl-labels
        ((visit
          (node)
          (let ((source (alist-get 'source node)))
            (dolist (entry (alist-get 'recipes node))
              (let* ((data (cdr entry))
                     (private (alist-get 'private data))
                     (local-name (alist-get 'name data))
                     (qualified-name (or (alist-get 'namepath data)
                                         local-name)))
                (when (or justl-include-private-recipes (not private))
                  (push
                   (list (make-recipe
                          :name qualified-name
                          :doc (alist-get 'doc data)
                          :parameters (alist-get 'parameters data)
                          :private private)
                         source
                         local-name)
                   rows))))
            (dolist (entry (alist-get 'modules node))
              (visit (cdr entry))))))
      (visit parsed))
    (nreverse rows)))

(defun my/justl-tabulated-entries (rows)
  "Convert flattened Just recipe ROWS into tabulated-list entries."
  (mapcar
   (lambda (row)
     (pcase-let ((`(,recipe ,source ,local-name) row))
       (let ((qualified-name (justl--recipe-name recipe)))
         (list
          qualified-name
          (vector
           (propertize qualified-name
                       'recipe recipe
                       'my/just-source source
                       'my/just-local-name local-name)
           (or (justl--recipe-desc recipe) ""))))))
   rows))

(defun my/justl-refresh-buffer ()
  "Refresh the current Justl buffer, including nested module recipes."
  (interactive)
  (unless justl-justfile
    (user-error "This Justl buffer has no root Justfile"))
  (setq tabulated-list-entries
        (my/justl-tabulated-entries
         (my/justl-recipes-with-modules justl-justfile)))
  (tabulated-list-print t))

(defun my/justl-open (justfile)
  "Open a Justl chooser for JUSTFILE, including all module recipes."
  (let* ((justfile (expand-file-name justfile))
         (directory (file-name-directory justfile))
         (buffer-name (format "*just [%s] *" justfile)))
    (justl--pop-to-buffer buffer-name)
    (with-current-buffer buffer-name
      (setq default-directory directory)
      (justl-mode)
      (setq-local justl-justfile justfile)
      (setq-local justl--last-justl-buffer buffer-name)
      (my/justl-refresh-buffer))))

(defun my/justl-exec-recipe ()
  "Run the Just recipe at point in a standard compilation buffer."
  (interactive)
  (let* ((recipe (justl--get-recipe-under-cursor))
         (recipe-name (justl--recipe-name recipe))
         (arguments
          (append
           (list justl-executable
                 (format "--justfile=%s" (file-local-name justl-justfile)))
           (transient-args 'justl-help-popup)
           (list recipe-name)
           (mapcar #'justl--read-arg (justl--recipe-args recipe))))
         (command (mapconcat #'shell-quote-argument arguments " "))
         (default-directory (file-name-directory justl-justfile)))
    ;; Justl's own process filter inserts text directly, bypassing
    ;; `compilation-filter' and therefore normal error parsing.  Use Emacs's
    ;; regular compilation pipeline, exactly as `M-x compile' does.
    (compilation-start command 'compilation-mode (lambda (_) "*just*"))))

(defun my/justl-go-to-recipe ()
  "Open the source definition of the root or module recipe at point."
  (interactive)
  (let* ((entry (tabulated-list-get-entry))
         (name-cell (and entry (aref entry 0)))
         (source (and name-cell
                      (get-text-property 0 'my/just-source name-cell)))
         (local-name (and name-cell
                          (get-text-property 0 'my/just-local-name name-cell))))
    (unless (and source local-name)
      (user-error "There is no recipe on the current line"))
    (find-file (if (file-name-absolute-p source)
                   source
                 (expand-file-name source
                                   (file-name-directory justl-justfile))))
    (goto-char (point-min))
    (when (re-search-forward
           (concat "^[@]?" (regexp-quote local-name) "\\(?: .*?\\)?:")
           nil t)
      (goto-char (line-beginning-position)))))

(defun my/justl-list-buffer-setup ()
  "Keep generated Just recipe table padding from looking like bad whitespace."
  (setq-local show-trailing-whitespace nil))

(defun my/justl-restore-compilation-errors ()
  "Let Just recipe output use normal compilation error matching."
  (kill-local-variable 'compilation-error-regexp-alist-alist)
  (kill-local-variable 'compilation-error-regexp-alist))

(defun my/helm-search-current-file-empty ()
  "Search the current file with an initially empty Helm input."
  (interactive)
  (helm-do-ag-this-file ""))

(defun my/helm-search-with-rg-options (command &rest arguments)
  "Call Helm-AG COMMAND with ARGUMENTS after prompting for RG options."
  (let ((helm-ag-always-set-extra-option t)
        ;; Prevent Helm-AG's separate prefix-driven extension prompt.
        (current-prefix-arg nil))
    (apply command arguments)))

(defun my/helm-search-current-file-with-rg-options ()
  "Search the current file after prompting for extra RG options."
  (interactive)
  (my/helm-search-with-rg-options #'helm-do-ag-this-file ""))

(defun my/helm-search-current-directory-with-rg-options ()
  "Search the current directory after prompting for extra RG options."
  (interactive)
  (my/helm-search-with-rg-options
   #'helm-do-ag (file-name-as-directory default-directory) nil ""))

(defun my/helm-search-project-with-rg-options ()
  "Search the current project after prompting for extra RG options."
  (interactive)
  (my/helm-search-with-rg-options #'helm-do-ag-project-root ""))

(defvar my/last-helm-ag-results-buffer nil
  "Most recently created or updated saved Helm-AG results buffer.")

(defun my/remember-helm-ag-results-buffer (&rest _)
  "Remember the current saved Helm-AG results buffer."
  (setq my/last-helm-ag-results-buffer (current-buffer)))

(defun my/latest-helm-ag-results-buffer ()
  "Return the most recent live saved Helm-AG results buffer."
  (or (and (buffer-live-p my/last-helm-ag-results-buffer)
           my/last-helm-ag-results-buffer)
      (get-buffer "*helm ag results*")
      (seq-find
       (lambda (buffer)
         (with-current-buffer buffer
           (derived-mode-p 'helm-ag-mode)))
       (buffer-list))))

(defun my/resume-last-search-buffer ()
  "Show the last saved Helm-AG results, or resume the last live search."
  (interactive)
  (let ((results (my/latest-helm-ag-results-buffer)))
    (cond
     (results
      (setq my/last-helm-ag-results-buffer results)
      (switch-to-buffer-other-window results))
     ((get-buffer "*helm-ag*")
      (helm-resume "*helm-ag*"))
     (t
      (user-error "No previous search buffer found")))))

(defun my/helm--next-candidate-across-sources ()
  "Move one Helm candidate forward, entering the next source at its end."
  (if (with-selected-window (helm-window)
        (helm-end-of-source-p))
      (helm-next-source)
    (helm-next-line 1)))

(defun my/helm--previous-candidate-across-sources ()
  "Move one Helm candidate backward, entering the previous source at its end."
  (if (with-selected-window (helm-window)
        (helm-beginning-of-source-p))
      (progn
        (helm-previous-source)
        ;; `helm-previous-source' lands on that source's first candidate.
        ;; Cycle once backward within it to reach its last candidate.
        (let ((helm-move-to-line-cycle-in-source t))
          (helm-previous-line 1)))
    (helm-previous-line 1)))

(defun my/helm-next-candidate-across-sources (&optional count)
  "Move COUNT Helm candidates forward, crossing source boundaries."
  (interactive "p")
  (setq count (or count 1))
  (let ((step (if (< count 0)
                  #'my/helm--previous-candidate-across-sources
                #'my/helm--next-candidate-across-sources)))
    (dotimes (_ (abs count))
      (funcall step))))

(defun my/helm-previous-candidate-across-sources (&optional count)
  "Move COUNT Helm candidates backward, crossing source boundaries."
  (interactive "p")
  (my/helm-next-candidate-across-sources (- (or count 1))))

(defun my/helm-ag-result-at-point-p ()
  "Return non-nil when point is on a saved Helm-AG result."
  (let ((line (buffer-substring-no-properties
               (line-beginning-position) (line-end-position))))
    (if helm-ag--search-this-file-p
        (string-match-p "\\`[0-9]+:" line)
      (and (helm-grep-split-line line) t))))

(defun my/helm-ag-results--seek (direction)
  "Move to the next saved Helm-AG result in DIRECTION."
  (let ((origin (point))
        found)
    (while (and (zerop (forward-line direction))
                (not (setq found (my/helm-ag-result-at-point-p)))))
    (unless found
      (goto-char origin)
      (user-error "No %s Helm-AG result"
                  (if (> direction 0) "next" "previous")))))

(defun my/helm-ag-results-preview ()
  "Preview the saved Helm-AG result at point without leaving its list."
  (interactive)
  (unless (my/helm-ag-result-at-point-p)
    (user-error "Point is not on a Helm-AG result"))
  (save-selected-window
    (helm-ag-mode-jump-other-window)))

(defun my/helm-ag-results-next (&optional count)
  "Move COUNT saved Helm-AG results forward and preview the destination."
  (interactive "p")
  (setq count (or count 1))
  (let ((direction (if (< count 0) -1 1)))
    (dotimes (_ (abs count))
      (my/helm-ag-results--seek direction)))
  (my/helm-ag-results-preview))

(defun my/helm-ag-results-previous (&optional count)
  "Move COUNT saved Helm-AG results backward and preview the destination."
  (interactive "p")
  (my/helm-ag-results-next (- (or count 1))))

(defun my/helm-ag-results-open ()
  "Open the saved Helm-AG result at point in its source window."
  (interactive)
  (unless (my/helm-ag-result-at-point-p)
    (user-error "Point is not on a Helm-AG result"))
  (helm-ag-mode-jump-other-window))

(defun my/helm-ag-omit-duplicate-current-file (original this-file)
  "Call ORIGINAL without passing THIS-FILE to ripgrep twice.
The pinned helm-ag fork adds a current-file target both as THIS-FILE and via
`helm-ag--default-target'.  Ripgrep then prints a filename, while helm-ag
expects only `line:text', causing every preview to jump to line zero."
  (let ((helm-ag--default-target
         (if this-file
             (seq-remove (lambda (target) (equal target this-file))
                         helm-ag--default-target)
           helm-ag--default-target)))
    (funcall original this-file)))

(defun my/helm-remember-origin-window ()
  "Keep Helm persistent actions in the exact window that launched Helm."
  (helm-set-local-variable 'helm-persistent-action-display-window
                           (selected-window))
  ;; The generic persistent-action hint consumes a full row and repeats a
  ;; binding the user already knows.  Hide it only in live Helm-AG searches.
  (when (equal helm-buffer "*helm-ag*")
    (helm-set-local-variable 'helm-display-header-line nil
                             'header-line-format nil)))

(defun my/helm-ag-disable-automatic-preview (&rest _)
  "Disable follow mode in the most recently constructed Helm-AG source."
  (when (bound-and-true-p helm-source-do-ag)
    (helm-set-attr 'follow nil helm-source-do-ag)))

(defun my/helm-ag-normalize-rg-option-values (input)
  "Normalize spaced value-taking RG options in Helm-AG INPUT.

Helm-AG's parser understands `--type=c' but treats the value in `--type c'
as part of the search pattern.  Ripgrep accepts both forms, so convert the
latter before Helm-AG separates command options from query text."
  (let ((normalized input))
    (dolist (option my/helm-ag-rg-options-with-values normalized)
      (setq normalized
            (replace-regexp-in-string
             (concat "\\(^\\|[[:space:]]+\\)"
                     "\\(" (regexp-quote option) "\\)"
                     "[[:space:]]+\\([^[:space:]]+\\)")
             "\\1\\2=\\3" normalized nil nil)))))

(defun my/helm-ag-parse-rg-options (original input)
  "Call Helm-AG parser ORIGINAL with normalized RG options from INPUT."
  (funcall original (my/helm-ag-normalize-rg-option-values input)))

(defun my/helm-find-recursively ()
  "Find files recursively below a prompted directory with Helm."
  (interactive)
  (require 'helm-find)
  (helm-find t))

(defun my/delete-window-and-split-right ()
  "Delete a window selected with Ace Window, then split to the right."
  (interactive)
  (call-interactively #'ace-delete-window)
  (split-window-right))

(defun my/split-window-below-and-focus ()
  "Split below and select the new window."
  (interactive)
  (select-window (split-window-below)))

(defun my/split-window-right-and-focus ()
  "Split right and select the new window."
  (interactive)
  (select-window (split-window-right)))

(defvar my/maximized-window-configuration nil)

(defun my/toggle-maximize-window ()
  "Maximize the selected window, or restore the previous layout."
  (interactive)
  (if (and my/maximized-window-configuration (one-window-p))
      (prog1 (set-window-configuration my/maximized-window-configuration)
        (setq my/maximized-window-configuration nil))
    (setq my/maximized-window-configuration (current-window-configuration))
    (delete-other-windows)))

(defun my/rotate-windows (count)
  "Rotate buffers through windows by COUNT places."
  (interactive "p")
  (let* ((windows (window-list nil 'no-minibuffer))
         (states (mapcar #'window-state-get windows))
         (window-count (length windows)))
    (when (< window-count 2)
      (user-error "Cannot rotate a single window"))
    (dotimes (index window-count)
      (window-state-put
       (nth index states)
       (nth (mod (+ index count) window-count) windows)))))

(defun my/rotate-windows-backward (count)
  "Rotate buffers backward through windows by COUNT places."
  (interactive "p")
  (my/rotate-windows (- count)))

(defun my/switch-to-minibuffer-window ()
  "Select the active minibuffer window."
  (interactive)
  (let ((window (active-minibuffer-window)))
    (if window
        (select-window window)
      (user-error "The minibuffer is not active"))))

(defun my/toggle-window-dedication ()
  "Toggle whether the selected window is dedicated to its buffer."
  (interactive)
  (let* ((window (selected-window))
         (dedicated (window-dedicated-p window)))
    (set-window-dedicated-p window (not dedicated))
    (message "Window %sdedicated" (if dedicated "no longer " ""))))

(defun my/open-tmux-window ()
  "Open a new tmux window rooted at `default-directory'."
  (interactive)
  (unless (executable-find "tmux")
    (user-error "tmux is not available on PATH"))
  (start-process "tmux-new-window" nil
                 (executable-find "tmux")
                 "new-window" "-c" (expand-file-name default-directory)))

(defun my/flyspell-correct-at-point ()
  "Correct the word at point using the Helm interface."
  (interactive)
  (require 'flyspell-correct-helm)
  (customize-set-variable 'flyspell-correct-interface
                          #'flyspell-correct-helm)
  (call-interactively #'flyspell-correct-at-point))

(defun my/clang-format-region-or-buffer (&optional style)
  "Format the active region, or the entire buffer, using clang-format.
Use STYLE when non-nil; otherwise honor the nearest .clang-format file."
  (interactive)
  (require 'clang-format)
  (save-excursion
    (if (use-region-p)
        (progn
          (clang-format-region (region-beginning) (region-end) style)
          (message "Formatted region"))
      (clang-format-buffer style)
      (message "Formatted buffer %s" (buffer-name)))))

(defun my/clang-format-function (&optional style)
  "Format the current C or C++ function using clang-format and STYLE."
  (interactive)
  (require 'clang-format)
  (save-excursion
    (c-mark-function)
    (clang-format (region-beginning) (region-end) style)
    (deactivate-mark)
    (message "Formatted function %s" (or (c-defun-name) "at point"))))

(defvar my/helm-project-return-directory nil
  "Project directory to re-enter after leaving a flat Projectile picker.")

(defun my/helm-projectile-parent-browser ()
  "Leave Projectile's flat file list and browse its parent with Helm."
  (interactive)
  (let* ((root (file-name-as-directory (projectile-project-root)))
         (parent (file-name-directory (directory-file-name root))))
    (setq my/helm-project-return-directory root)
    (helm-run-after-exit #'helm-find-files-1 parent)))

(defun my/helm-find-files-forward ()
  "Return to a project left with `C-h', or enter Helm's last child."
  (interactive)
  (if my/helm-project-return-directory
      (let ((directory my/helm-project-return-directory))
        (setq my/helm-project-return-directory nil)
        (helm-run-after-exit #'helm-find-files-1 directory))
    (helm-find-files-down-last-level)))

(defvar my/helm-ag-directory-stack nil
  "Directories left through parent navigation in a Helm Ag session.")

(defvar my/helm-ag-navigation-in-progress nil)

(defun my/helm-ag-reset-directory-stack (original &rest arguments)
  "Reset parent navigation before calling ORIGINAL with ARGUMENTS."
  (unless my/helm-ag-navigation-in-progress
    (setq my/helm-ag-directory-stack nil))
  (apply original arguments))

(defun my/helm-ag-up-one-level ()
  "Search one directory higher with synchronous Helm Ag."
  (interactive)
  (push (file-name-as-directory default-directory)
        my/helm-ag-directory-stack)
  (helm-ag--up-one-level))

(defun my/helm-do-ag-up-one-level ()
  "Search one directory higher with asynchronous Helm Ag."
  (interactive)
  (push (file-name-as-directory default-directory)
        my/helm-ag-directory-stack)
  (helm-ag--do-ag-up-one-level))

(defun my/helm-ag-down-one-level ()
  "Return to the most recently left Helm Ag search directory."
  (interactive)
  (if-let ((directory (pop my/helm-ag-directory-stack)))
      (let ((input helm-input))
        (helm-run-after-exit
         (lambda ()
           (let ((my/helm-ag-navigation-in-progress t))
             (helm-do-ag directory nil input)))))
    (user-error "No child search directory to return to")))

(defun my/project-tags-file (root)
  "Return a profile-local, distinct tags file for project ROOT."
  (let* ((directory-name
          (file-name-nondirectory (directory-file-name root)))
         (safe-name (replace-regexp-in-string "[^[:alnum:]_.-]" "_"
                                              directory-name))
         (digest (substring (secure-hash 'sha1 (expand-file-name root)) 0 12)))
    (expand-file-name (format "%s-%s-TAGS" safe-name digest)
                      my/tags-directory)))

(defun my/rebuild-project-tags ()
  "Discard and immediately rebuild automatic ETAGS for this project."
  (interactive)
  (require 'project)
  (unless (require 'etags-regen nil t)
    (user-error "This Emacs installation does not provide etags-regen"))
  (let ((program (my/etags-executable)))
    (unless program
      (user-error "Cannot find etags on PATH"))
    (setq etags-regen-program program)
    (let* ((project (project-current t))
           (root (project-root project))
           (tags-file (my/project-tags-file root)))
      (etags-regen--tags-cleanup)
      (when-let ((buffer (get-file-buffer tags-file)))
        (kill-buffer buffer))
      (when (file-exists-p tags-file)
        (delete-file tags-file))
      (tags-reset-tags-tables)
      (etags-regen--tags-generate project)
      (message "Rebuilt tags for %s" (abbreviate-file-name root)))))

(defun my/disable-flymake ()
  "Keep automatic code diagnostics disabled in this profile."
  (when (bound-and-true-p flymake-mode)
    (flymake-mode -1)))

(add-hook 'flymake-mode-hook #'my/disable-flymake)

;;; Dashboard support

(defun my/nerd-icons-font-available-p ()
  "Return non-nil when the Symbols Nerd Font is installed."
  (and (display-graphic-p)
       (find-font (font-spec :family "Symbols Nerd Font Mono"))))

;;; Native leader keymaps

(defvar-keymap my/leader-buffer-map
  :doc "Buffer commands."
  :name "buffers"
  "b" #'helm-mini
  "d" #'kill-current-buffer
  "h" #'dashboard-open
  "n" #'next-buffer
  "p" #'previous-buffer
  "R" #'revert-buffer
  "s" #'scratch-buffer
  "w" #'read-only-mode
  "x" #'kill-buffer-and-window)

(defvar-keymap my/leader-file-map
  :doc "File commands."
  :name "files"
  "b" #'helm-filtered-bookmarks
  "f" #'helm-find-files
  "j" #'dired-jump
  "r" #'helm-recentf
  "s" #'save-buffer
  "S" #'save-some-buffers)

(defvar-keymap my/leader-project-map
  :doc "Project commands."
  :name "projects"
  "!" #'projectile-run-shell-command-in-root
  "&" #'projectile-run-async-shell-command-in-root
  "%" #'projectile-replace-regexp
  "b" #'helm-projectile-switch-to-buffer
  "c" #'projectile-compile-project
  "u" #'projectile-run-project
  "d" #'helm-projectile-find-dir
  "D" #'projectile-dired
  "E" #'projectile-find-references
  "f" #'helm-projectile-find-file
  "F" #'helm-projectile-find-file-dwim
  "g" #'xref-find-definitions
  "G" #'my/rebuild-project-tags
  "I" #'projectile-invalidate-cache
  "k" #'projectile-kill-buffers
  "/" #'helm-do-ag-project-root
  "p" #'helm-projectile-switch-project
  "r" #'projectile-recentf
  "R" #'projectile-replace
  "T" #'projectile-test-project
  "v" #'projectile-vc)

(defvar-keymap my/leader-search-ag-map
  :doc "Spacemacs-compatible helm-ag aliases."
  :name "helm-ag"
  "a" #'helm-do-ag-this-file
  "d" #'helm-do-ag
  "p" #'helm-do-ag-project-root)

(defvar-keymap my/leader-search-options-map
  :doc "Helm-AG searches with extra Ripgrep options."
  :name "rg options"
  "d" #'my/helm-search-current-directory-with-rg-options
  "p" #'my/helm-search-project-with-rg-options
  "s" #'my/helm-search-current-file-with-rg-options)

(defvar-keymap my/leader-search-map
  :doc "Search commands."
  :name "search"
  "P" #'helm-do-ag-project-root
  "S" #'helm-do-ag-this-file
  "a" my/leader-search-ag-map
  "d" #'helm-do-ag
  "e" #'evil-iedit-state/iedit-mode
  "l" #'my/resume-last-search-buffer
  "o" my/leader-search-options-map
  "p" #'helm-do-ag-project-root
  "s" #'my/helm-search-current-file-empty)

(defvar-keymap my/leader-git-file-map
  :doc "Git file commands."
  :name "files"
  "F" #'magit-find-file
  "d" #'magit-diff
  "l" #'magit-log-buffer-file
  "m" #'magit-file-dispatch)

(defvar-keymap my/leader-git-map
  :doc "Git commands."
  :name "git"
  "c" #'magit-clone
  "f" my/leader-git-file-map
  "i" #'magit-init
  "L" #'magit-list-repositories
  "m" #'magit-dispatch
  "s" #'magit-status
  "S" #'magit-stage-files
  "U" #'magit-unstage-files)

(defvar-keymap my/leader-compilation-map
  :doc "Compilation commands."
  :name "compile"
  "C" #'compile
  "F" #'clang-format-buffer
  "N" #'previous-error
  "c" #'compile
  "f" #'my/clang-format-region-or-buffer
  "j" #'my/just-choose-recipe
  "k" #'kill-compilation
  "n" #'next-error
  "r" #'recompile)

(defvar-keymap my/c-c++-format-map
  :doc "C/C++ formatting commands."
  :name "format"
  "=" #'my/clang-format-region-or-buffer
  "f" #'my/clang-format-function)

(defvar-keymap my/c-c++-leader-map
  :doc "C/C++ commands."
  :name "C/C++"
  "=" my/c-c++-format-map)

(defvar-keymap my/leader-org-map
  :doc "Org commands."
  :name "org"
  "a" #'org-agenda-list
  "c" #'org-capture
  "l" #'org-store-link
  "o" #'org-agenda)

(defvar-keymap my/leader-shell-map
  :doc "Shell commands."
  :name "shells"
  "v" #'shell-pop)

(defvar-keymap my/leader-terminal-map
  :doc "Terminal commands."
  :name "terminals"
  "s" my/leader-shell-map)

(defvar-keymap my/leader-app-map
  :doc "Application commands."
  :name "applications"
  "d" #'dired
  "o" my/leader-org-map
  "t" my/leader-terminal-map)

(defvar-keymap my/leader-jump-map
  :doc "Jump commands."
  :name "jump"
  "d" #'dired-jump
  "D" #'dired-jump-other-window)

(defvar-keymap my/leader-help-describe-map
  :doc "Describe commands."
  :name "describe"
  "b" #'describe-bindings
  "f" #'describe-function
  "k" #'describe-key
  "m" #'describe-mode
  "v" #'describe-variable)

(defvar-keymap my/leader-help-map
  :doc "Help commands."
  :name "help"
  "d" my/leader-help-describe-map)

(defvar-keymap my/leader-custom-map
  :doc "Personal commands."
  :name "custom"
  "d" #'my/delete-window-and-split-right
  "f" #'my/helm-find-recursively
  "o" #'ff-find-other-file
  "t" #'my/open-tmux-window)

(defvar-keymap my/leader-narrow-map
  :doc "Narrowing commands."
  :name "narrow"
  "s" #'org-toggle-narrow-to-subtree)

(defvar-keymap my/leader-spelling-map
  :doc "Spelling commands."
  :name "spelling"
  "n" #'flyspell-goto-next-error
  "s" #'my/flyspell-correct-at-point)

(defvar-keymap my/leader-toggle-map
  :doc "Toggle commands."
  :name "toggles"
  "S" #'flyspell-mode)

(defvar-keymap my/leader-window-map
  :doc "Window commands."
  :name "windows"
  "TAB" #'other-window
  "/" #'split-window-right
  "-" #'split-window-below
  "=" #'balance-windows-area
  "H" #'evil-window-move-far-left
  "J" #'evil-window-move-very-bottom
  "K" #'evil-window-move-very-top
  "L" #'evil-window-move-far-right
  "R" #'my/rotate-windows-backward
  "S" #'my/split-window-below-and-focus
  "U" #'winner-redo
  "V" #'my/split-window-right-and-focus
  "[" #'shrink-window-horizontally
  "]" #'enlarge-window-horizontally
  "b" #'my/switch-to-minibuffer-window
  "d" #'delete-window
  "f" #'follow-mode
  "h" #'evil-window-left
  "j" #'evil-window-down
  "k" #'evil-window-up
  "l" #'evil-window-right
  "m" #'my/toggle-maximize-window
  "o" #'other-frame
  "r" #'my/rotate-windows
  "s" #'split-window-below
  "t" #'my/toggle-window-dedication
  "u" #'winner-undo
  "v" #'split-window-right
  "w" #'other-window
  "x" #'kill-buffer-and-window
  "{" #'shrink-window
  "}" #'enlarge-window)

(defvar-keymap my/leader-map
  :doc "Main leader map."
  :name "leader"
  "TAB" #'my/alternate-buffer
  "<tab>" #'my/alternate-buffer
  "1" #'winum-select-window-1
  "2" #'winum-select-window-2
  "3" #'winum-select-window-3
  "4" #'winum-select-window-4
  "5" #'winum-select-window-5
  "6" #'winum-select-window-6
  "7" #'winum-select-window-7
  "8" #'winum-select-window-8
  "9" #'winum-select-window-9
  "e" #'helm-M-x
  "*" #'helm-do-ag-project-root
  "'" #'shell-pop
  "/" #'helm-do-ag-project-root
  "S" my/leader-spelling-map
  "a" my/leader-app-map
  "b" my/leader-buffer-map
  "c" my/leader-compilation-map
  "d" my/leader-custom-map
  "f" my/leader-file-map
  "g" my/leader-git-map
  "h" my/leader-help-map
  "j" my/leader-jump-map
  "n" my/leader-narrow-map
  "p" my/leader-project-map
  "s" my/leader-search-map
  "t" my/leader-toggle-map
  "v" #'er/expand-region
  "w" my/leader-window-map)

;; `defvar-keymap' intentionally preserves an existing value.  Set additions
;; explicitly too, so evaluating init.el in a running Emacs updates the map.
(keymap-unset my/leader-map "SPC")
(keymap-set my/leader-map "TAB" #'my/alternate-buffer)
(keymap-set my/leader-map "<tab>" #'my/alternate-buffer)
(keymap-set my/leader-map "e" #'helm-M-x)
(keymap-set my/leader-map "*" #'helm-do-ag-project-root)
(keymap-set my/leader-map "b h" #'dashboard-open)
(keymap-set my/leader-map "f s" #'save-buffer)
(keymap-set my/leader-map "c f" #'my/clang-format-region-or-buffer)
(keymap-set my/leader-map "c F" #'clang-format-buffer)
(keymap-set my/leader-map "c j" #'my/just-choose-recipe)
(keymap-set my/leader-map "j d" #'dired-jump)
(keymap-set my/leader-map "j D" #'dired-jump-other-window)
(keymap-set my/leader-map "s e" #'evil-iedit-state/iedit-mode)
(keymap-set my/leader-map "s l" #'my/resume-last-search-buffer)
(keymap-set my/leader-map "s o" my/leader-search-options-map)
(keymap-set my/leader-map "s s" #'my/helm-search-current-file-empty)
(keymap-set my/leader-map "s S" #'helm-do-ag-this-file)
(keymap-set my/leader-map "v" #'er/expand-region)

;;; Evil and key discovery

(use-package evil
  :demand t
  :config
  (evil-mode 1)
  (evil-define-key '(normal motion visual) 'global
    (kbd "C-u") #'evil-scroll-up)
  (evil-define-key '(normal motion) 'global
    (kbd "g b") #'xref-go-back
    (kbd "g d") #'xref-find-definitions
    (kbd "g D") #'xref-find-definitions-other-window
    (kbd "g f") #'find-file-at-point
    (kbd "g r") #'xref-find-references)
  (evil-define-key '(normal motion visual) 'global (kbd "SPC") my/leader-map)
  (evil-define-key '(insert emacs) 'global (kbd "M-m") my/leader-map))

(defun my/bind-leader-in-keymap (map)
  "Make the global leader authoritative in Evil states for MAP."
  (let ((keymap (if (symbolp map)
                    (and (boundp map) (symbol-value map))
                  map)))
    (when (keymapp keymap)
      (evil-define-key* '(normal motion visual) keymap
                        (kbd "SPC") my/leader-map))))

(defun my/evil-collection-local-bindings (mode maps)
  "Apply personal bindings after Evil Collection configures MODE."
  (dolist (map maps)
    (my/bind-leader-in-keymap map))
  (when (eq mode 'dired)
    (evil-define-key 'normal dired-mode-map
      (kbd "C-h") #'dired-up-directory
      (kbd "C-l") #'dired-find-alternate-file
      (kbd "h") #'dired-up-directory
      (kbd "l") #'dired-find-alternate-file)))

(use-package evil-collection
  :demand t
  :after evil
  :init
  (setq evil-collection-key-blacklist '("SPC"))
  :config
  (add-hook 'evil-collection-setup-hook #'my/evil-collection-local-bindings)
  (evil-collection-init))

(use-package which-key
  :ensure nil
  :demand t
  :custom
  (which-key-idle-delay 0.4)
  :config
  (which-key-mode 1)
  (which-key-add-keymap-based-replacements
    my/leader-map
    "TAB" "last buffer"
    "<tab>" "last buffer"
    "S" "spelling"
    "a" "applications"
    "b" "buffers"
    "c" "compile"
    "d" "custom"
    "e" "commands"
    "f" "files"
    "g" "git"
    "h" "help"
    "j" "jump"
    "n" "narrow"
    "p" "projects"
    "s" "search"
    "t" "toggles"
    "w" "windows")
  (which-key-add-keymap-based-replacements
    my/leader-search-map
    "l" "last search"
    "o" "rg options")
  (which-key-add-keymap-based-replacements
    my/leader-compilation-map
    "j" "just recipes"))

(winner-mode 1)

(use-package winum
  :demand t
  :custom
  (winum-auto-assign-0-to-minibuffer nil)
  ;; Doom Modeline renders the number; Winum only assigns it.
  (winum-auto-setup-mode-line nil)
  (winum-ignored-buffers '(" *which-key*"))
  :config
  (winum-mode 1))

;; Helm overrides these below with candidate navigation.  For other prompts,
;; C-j/C-k move through minibuffer history and Escape cancels immediately.
(dolist (map (list minibuffer-local-map
                   minibuffer-local-completion-map
                   minibuffer-local-must-match-map
                   minibuffer-local-filename-completion-map))
  (keymap-set map "C-j" #'next-history-element)
  (keymap-set map "C-k" #'previous-history-element)
  (keymap-set map "<escape>" #'abort-recursive-edit))

(keymap-global-set "C-k" #'drag-stuff-up)
(keymap-global-set "C-j" #'drag-stuff-down)
(keymap-global-set "C-l" #'duplicate-line)

;;; Helm, projects, and search

(use-package helm
  :defer t
  :commands (helm-M-x
             helm-mini
             helm-buffers-list
             helm-filtered-bookmarks
             helm-find-files
             helm-recentf)
  :bind (("M-x" . helm-M-x)
         ("C-x C-f" . helm-find-files)
         ("C-x b" . helm-buffers-list))
  :custom
  ;; Keep movement and preview separate, as in the manual Helm workflow:
  ;; C-j/C-k select a candidate and TAB explicitly previews it.
  (helm-follow-mode-persistent nil)
  ;; Used only if follow mode is toggled on manually for a Helm source.
  (helm-follow-input-idle-delay 0.001)
  ;; Preserve every existing window.  Helm's default display path deletes
  ;; other windows when auto-resize is active unless splitting inside is set.
  (helm-split-window-inside-p t)
  (helm-always-two-windows t)
  (helm-full-frame nil)
  (helm-default-display-buffer-functions '(display-buffer-in-side-window))
  (helm-default-display-buffer-alist
   '((inhibit-same-window . t)
     (side . bottom)
     (window-height . 0.4)))
  (helm-M-x-fuzzy-match t)
  ;; SPC e shows recent commands first, in actual recency order, followed by
  ;; every interactive Emacs command.  Do not hide commands merely because
  ;; their `interactive' declaration names a different mode.
  (helm-M-x-reverse-history nil)
  (helm-M-x-history-transformer-sort nil)
  (helm-M-x-exclude-unusable-commands-in-mode nil)
  (helm-M-x-always-save-history t)
  (helm-buffers-fuzzy-matching t)
  (helm-recentf-fuzzy-match t)
  (helm-autoresize-max-height 40)
  (helm-autoresize-min-height 20)
  (helm-grep-ag-command
   "rg --color=always --smart-case --no-heading --line-number %s -- %s %s")
  :config
  (add-hook 'helm-before-initialize-hook #'my/helm-remember-origin-window)
  ;; Helm normally hides all buffers beginning with "*helm".  Saved F3
  ;; search results are real, persistent result buffers and should remain
  ;; reachable from the ordinary buffer list.
  (add-to-list 'helm-white-buffer-regexp-list
               "\\`\\*helm ag results")
  ;; Use the ordinary arrow keys to edit Helm's input pattern.  Candidate
  ;; movement remains on C-j/C-k; source movement remains available through
  ;; Helm's existing C-o and bracket bindings.
  (keymap-set helm-map "<left>" #'backward-char)
  (keymap-set helm-map "<right>" #'forward-char)
  (keymap-set helm-map "C-j" #'my/helm-next-candidate-across-sources)
  (keymap-set helm-map "C-k" #'my/helm-previous-candidate-across-sources)
  (evil-define-key '(normal insert motion) helm-map
    (kbd "C-j") #'my/helm-next-candidate-across-sources
    (kbd "C-k") #'my/helm-previous-candidate-across-sources
    (kbd "C-u") #'helm-previous-page
    (kbd "C-d") #'helm-next-page
    (kbd "TAB") #'helm-execute-persistent-action
    (kbd "<tab>") #'helm-execute-persistent-action)
  (keymap-set helm-map "C-u" #'helm-previous-page)
  (keymap-set helm-map "C-d" #'helm-next-page)
  (keymap-set helm-map "TAB" #'helm-execute-persistent-action)
  (keymap-set helm-map "<tab>" #'helm-execute-persistent-action)
  (keymap-set helm-map "C-z" #'helm-select-action)
  (keymap-set helm-map "<escape>" #'helm-keyboard-quit)
  (keymap-set helm-find-files-map "C-h" #'helm-find-files-up-one-level)
  (keymap-set helm-find-files-map "C-l" #'my/helm-find-files-forward)
  (helm-autoresize-mode 1))

(use-package projectile
  :defer t
  :commands (projectile-compile-project
             projectile-dired
             projectile-find-references
             projectile-invalidate-cache
             projectile-kill-buffers
             projectile-project-root
             projectile-recentf
             projectile-replace
             projectile-replace-regexp
             projectile-run-async-shell-command-in-root
             projectile-run-project
             projectile-run-shell-command-in-root
             projectile-test-project
             projectile-vc)
  :init
  (setq projectile-completion-system 'helm
        projectile-indexing-method 'hybrid
        projectile-enable-caching t
        projectile-cache-file (expand-file-name "projectile-cache.el" my/var-directory)
        projectile-frecency-file
        (expand-file-name "projectile-frecency.eld" my/var-directory)
        projectile-known-projects-file
        (expand-file-name "projectile-bookmarks.eld" my/var-directory)))

(use-package daily-worklog
  :ensure nil
  :load-path "lisp"
  :demand t
  :custom
  (daily-worklog-directory
   (expand-file-name "daily-worklog/" my/var-directory))
  (daily-worklog-save-interval 900)
  :config
  (daily-worklog-mode 1))

(use-package helm-projectile
  :defer t
  :after (helm projectile)
  :commands (helm-projectile
             helm-projectile-rg
             helm-projectile-find-dir
             helm-projectile-find-file
             helm-projectile-find-file-dwim
             helm-projectile-switch-project
             helm-projectile-switch-to-buffer)
  :init
  (setq projectile-switch-project-action #'helm-projectile
        helm-projectile-set-input-automatically t)
  :config
  (keymap-set helm-projectile-find-file-map
              "C-h" #'my/helm-projectile-parent-browser)
  (helm-projectile-mode 1))

(use-package nerd-icons
  :defer t)

(defun my/register-recent-projects ()
  "Teach Projectile about Git projects represented in `recentf-list'."
  (let ((projects
         (delete-dups
          (delq nil
                (mapcar
                 (lambda (file)
                   (unless (file-remote-p file)
                     (let ((directory (file-name-directory
                                       (expand-file-name file))))
                       (when (file-directory-p directory)
                         (or (locate-dominating-file directory ".projectile")
                             (locate-dominating-file directory ".git"))))))
                 recentf-list)))))
    (unless (seq-every-p (lambda (root)
                           (member root projectile-known-projects))
                         projects)
      (setq projectile-known-projects
            (delete-dups (append projects projectile-known-projects)))
      (projectile-save-known-projects))))

(use-package dashboard
  :demand t
  :init
  (setq dashboard-startup-banner 'official
        dashboard-banner-logo-title "Welcome back"
        dashboard-center-content t
        dashboard-vertically-center-content t
        dashboard-navigation-cycle t
        dashboard-projects-backend 'projectile
        dashboard-items '((recents . 8)
                          (projects . 8))
        dashboard-item-shortcuts '((recents . "r")
                                   (projects . "p"))
        dashboard-set-heading-icons t
        dashboard-set-file-icons t
        dashboard-icon-type 'nerd-icons
        dashboard-display-icons-p (my/nerd-icons-font-available-p)
        dashboard-set-init-info t
        dashboard-footer-messages
        '("SPC e commands  •  SPC p p projects  •  SPC f f files"))
  :config
  (require 'projectile)
  (projectile-mode 1)
  (my/register-recent-projects)
  (dashboard-setup-startup-hook)
  (evil-set-initial-state 'dashboard-mode 'motion)
  (my/bind-leader-in-keymap dashboard-mode-map))

(use-package helm-ag
  :defer t
  :after helm
  :commands (helm-do-ag
             helm-do-ag-project-root
             helm-do-ag-this-file)
  :custom
  (helm-ag-base-command
   "rg --smart-case --no-heading --color=never --line-number")
  (helm-ag-insert-at-point 'symbol)
  (helm-ag-success-exit-status '(0 1))
  (helm-ag-use-grep-ignore-list t)
  :config
  ;; `helm-ag-source' may have been created with follow mode enabled before a
  ;; live init.el reload.  Reset both the static and future async sources.
  (helm-set-attr 'follow nil helm-ag-source)
  (my/helm-ag-disable-automatic-preview)
  (unless (advice-member-p #'my/helm-ag-disable-automatic-preview
                           'helm-ag--do-ag-set-source)
    (advice-add 'helm-ag--do-ag-set-source :after
                #'my/helm-ag-disable-automatic-preview))
  (unless (advice-member-p #'my/helm-ag-parse-rg-options
                         'helm-ag--parse-options-and-query)
    (advice-add 'helm-ag--parse-options-and-query :around
                #'my/helm-ag-parse-rg-options))
  (unless (advice-member-p #'my/remember-helm-ag-results-buffer
                           'helm-ag--put-result-in-save-buffer)
    (advice-add 'helm-ag--put-result-in-save-buffer :after
                #'my/remember-helm-ag-results-buffer))
  ;; Helm-AG otherwise replaces the base Helm arrow bindings with
  ;; previous/next-file commands, making its query and RG options awkward to
  ;; edit.  C-j/C-k already handle result navigation.
  (dolist (map (list helm-ag-map helm-do-ag-map))
    (keymap-set map "<left>" #'backward-char)
    (keymap-set map "<right>" #'forward-char))
  (keymap-set helm-ag-map "C-h" #'my/helm-ag-up-one-level)
  (keymap-set helm-ag-map "C-l" #'my/helm-ag-down-one-level)
  (keymap-set helm-do-ag-map "C-h" #'my/helm-do-ag-up-one-level)
  (keymap-set helm-do-ag-map "C-l" #'my/helm-ag-down-one-level)
  (my/bind-leader-in-keymap helm-ag-edit-map)
  ;; Spacemacs makes saved Helm-AG buffers next-error capable.  These local
  ;; bindings provide the same preview workflow directly from the result list.
  (keymap-set helm-ag-mode-map "C-j" #'my/helm-ag-results-next)
  (keymap-set helm-ag-mode-map "C-k" #'my/helm-ag-results-previous)
  (keymap-set helm-ag-mode-map "RET" #'my/helm-ag-results-open)
  (keymap-set helm-ag-mode-map "<return>" #'my/helm-ag-results-open)
  (keymap-set helm-ag-mode-map "q" #'quit-window)
  (evil-set-initial-state 'helm-ag-mode 'motion)
  (evil-define-key* '(normal motion) helm-ag-mode-map
    (kbd "C-j") #'my/helm-ag-results-next
    (kbd "C-k") #'my/helm-ag-results-previous
    (kbd "RET") #'my/helm-ag-results-open
    (kbd "q") #'quit-window)
  (my/bind-leader-in-keymap helm-ag-mode-map)
  (unless (advice-member-p #'my/helm-ag-reset-directory-stack 'helm-do-ag)
    (advice-add 'helm-do-ag :around #'my/helm-ag-reset-directory-stack))
  (unless (advice-member-p #'my/helm-ag-omit-duplicate-current-file
                           'helm-ag--construct-command)
    (advice-add 'helm-ag--construct-command :around
                #'my/helm-ag-omit-duplicate-current-file)))

;;; Automatic project tags and xref

(setq etags-regen-program (or (my/etags-executable) "etags")
      etags-regen-tags-file #'my/project-tags-file
      etags-regen-ignores
      '("build" "build-*" "cmake-build-*" "dist" "target"
        "node_modules" ".cache" ".venv" "venv" "vendor" "third_party"))

(cond
 ((not (require 'etags-regen nil t))
  (message "Automatic project tags disabled: etags-regen is unavailable"))
 ((not (my/etags-executable))
  (message "Automatic project tags disabled: cannot find etags on PATH"))
 (t
  (etags-regen-mode 1)))

(with-eval-after-load 'xref
  ;; Like Spacemacs' evilified Xref buffer, keep navigation in the results
  ;; window.  Xref's line commands preview in the source window themselves.
  (keymap-set xref--xref-buffer-mode-map "C-j" #'xref-next-line)
  (keymap-set xref--xref-buffer-mode-map "C-k" #'xref-prev-line)
  (keymap-set xref--xref-buffer-mode-map "RET" #'xref-goto-xref)
  (keymap-set xref--xref-buffer-mode-map "<return>" #'xref-goto-xref)
  (keymap-set xref--xref-buffer-mode-map "C-h" #'xref-go-back)
  (keymap-set xref--xref-buffer-mode-map "C-l" #'xref-go-forward)
  (evil-set-initial-state 'xref--xref-buffer-mode 'motion)
  (evil-define-key* '(normal motion) xref--xref-buffer-mode-map
    (kbd "C-j") #'xref-next-line
    (kbd "C-k") #'xref-prev-line
    (kbd "RET") #'xref-goto-xref)
  (my/bind-leader-in-keymap xref--xref-buffer-mode-map))

;;; Magit, compilation, Dired, and terminal

(use-package just-mode
  :defer t
  :mode (("\\(?:^\\|/\\)\\(?:[Jj]ustfile\\|\\.justfile\\)\\'" . just-mode)
         ("\\.just\\'" . just-mode)))

(use-package justl
  :defer t
  :commands justl
  :hook ((justl-mode . my/justl-list-buffer-setup)
         (justl-module-mode . my/justl-list-buffer-setup)
         (justl-compile-mode . my/justl-restore-compilation-errors))
  :config
  ;; Make the recipe list act like the other selection buffers in this
  ;; profile: C-j/C-k move, RET or e runs, o opens the recipe definition.
  (keymap-set justl-mode-map "C-j" #'next-line)
  (keymap-set justl-mode-map "C-k" #'previous-line)
  (keymap-set justl-mode-map "g" #'my/justl-refresh-buffer)
  (keymap-set justl-mode-map "RET" #'my/justl-exec-recipe)
  (keymap-set justl-mode-map "<return>" #'my/justl-exec-recipe)
  (keymap-set justl-mode-map "e" #'my/justl-exec-recipe)
  (keymap-set justl-mode-map "o" #'my/justl-go-to-recipe)
  (keymap-set justl-mode-map "q" #'quit-window)
  (keymap-set justl-compile-mode-map "q" #'quit-window)
  (evil-set-initial-state 'justl-mode 'motion)
  (evil-define-key* '(normal motion) justl-mode-map
    (kbd "C-j") #'next-line
    (kbd "C-k") #'previous-line
    (kbd "RET") #'my/justl-exec-recipe
    (kbd "e") #'my/justl-exec-recipe
    (kbd "o") #'my/justl-go-to-recipe
    (kbd "q") #'quit-window)
  (my/bind-leader-in-keymap justl-mode-map)
  (my/bind-leader-in-keymap justl-compile-mode-map))

(use-package magit
  :defer t
  :commands (magit-clone
             magit-diff
             magit-dispatch
             magit-file-dispatch
             magit-find-file
             magit-init
             magit-list-repositories
             magit-log-buffer-file
             magit-stage-files
             magit-status
             magit-unstage-files)
  :config
  (my/bind-leader-in-keymap magit-mode-map))

(with-eval-after-load 'compile
  (my/bind-leader-in-keymap compilation-mode-map))

(with-eval-after-load 'dired
  (my/bind-leader-in-keymap dired-mode-map)
  (evil-define-key '(normal motion) dired-mode-map
    (kbd "C-h") #'dired-up-directory
    (kbd "C-l") #'dired-find-alternate-file
    (kbd "h") #'dired-up-directory
    (kbd "l") #'dired-find-alternate-file))

(use-package treemacs-icons-dired
  :defer t
  :commands treemacs-icons-dired-mode
  :init
  (setq treemacs-persist-file
        (expand-file-name "treemacs-persist" my/var-directory)
        treemacs-last-error-persist-file
        (expand-file-name "treemacs-persist-at-last-error" my/var-directory))
  :hook (dired-mode . treemacs-icons-dired-enable-once))

(use-package ace-window
  :defer t
  :commands ace-delete-window)

(use-package drag-stuff
  :defer t
  :commands (drag-stuff-up drag-stuff-down))

(use-package shell-pop
  :defer t
  :commands shell-pop
  :init
  (setq shell-pop-window-position "right"
        shell-pop-window-size 50
        shell-pop-full-span t
        shell-pop-autocd-to-working-dir t)
  :config
  (customize-set-variable
   'shell-pop-shell-type
   '("vterm" "*vterm*" (lambda () (vterm)))))

(use-package vterm
  :defer t
  :commands vterm
  :init
  (setq vterm-shell (or (getenv "SHELL") shell-file-name)
        vterm-max-scrollback 10000
        vterm-always-compile-module t)
  :config
  (my/bind-leader-in-keymap vterm-mode-map))

(use-package evil-iedit-state
  :defer t
  :commands evil-iedit-state/iedit-mode
  :config
  (set-face-attribute 'iedit-occurrence nil
                      :inherit 'error :foreground 'unspecified
                      :background 'unspecified :weight 'bold)
  (keymap-set evil-iedit-state-map "SPC" my/leader-map))

;;; Completion and language modes

(use-package expand-region
  :defer t
  :commands er/expand-region
  :custom
  (expand-region-contract-fast-key "V")
  (expand-region-reset-fast-key "r"))

(use-package clang-format
  :defer t
  :commands (clang-format-buffer clang-format-region)
  :custom
  (clang-format-executable
   (or (executable-find "clang-format")
       (and (eq system-type 'darwin)
            (file-executable-p
             "/Library/Developer/CommandLineTools/usr/bin/clang-format")
            "/Library/Developer/CommandLineTools/usr/bin/clang-format")
       "clang-format"))
  ;; Prefer a project's .clang-format; remain useful when it has none.
  (clang-format-fallback-style "LLVM"))

(with-eval-after-load 'cc-mode
  (evil-define-key '(normal motion) c-mode-map
    (kbd ",") my/c-c++-leader-map)
  (evil-define-key '(normal motion) c++-mode-map
    (kbd ",") my/c-c++-leader-map))

(defun my/company-setup ()
  "Enable a small set of useful Company backends in this buffer."
  (setq-local company-backends
              '((company-capf
                 company-files
                 company-keywords
                 company-dabbrev-code
                 company-dabbrev)))
  (company-mode 1))

(use-package company
  :defer t
  :commands company-mode
  :hook ((python-mode . my/company-setup)
         (c-mode . my/company-setup)
         (c++-mode . my/company-setup)
         (org-mode . my/company-setup))
  :custom
  (company-idle-delay 0.2)
  (company-minimum-prefix-length 2)
  (company-require-match nil)
  (company-dabbrev-ignore-case nil)
  (company-dabbrev-downcase nil)
  :config
  (keymap-set company-active-map "C-j" #'company-select-next)
  (keymap-set company-active-map "C-k" #'company-select-previous)
  (keymap-set company-active-map "TAB" #'company-complete-common-or-cycle)
  (keymap-set company-active-map "RET" #'company-complete-selection))

(setq python-shell-interpreter my/python-program
      python-indent-offset 4)

(defun my/python-mode-settings ()
  "Use the Python layout from the previous configuration."
  (setq-local fill-column 79
              tab-width 4))

(add-hook 'python-mode-hook #'my/python-mode-settings)

;;; Spelling

(when-let ((checker (my/spell-checker-executable)))
  (setq ispell-program-name checker))

(setq ispell-dictionary "en_US"
      ispell-personal-dictionary (expand-file-name "personal-dictionary" my/var-directory))

(when (and (eq system-type 'darwin)
           (string-match-p "hunspell\\'" (or ispell-program-name "")))
  (setenv "DICPATH" (expand-file-name "~/Library/Spelling")))

(defun my/enable-flyspell ()
  "Enable Flyspell when a supported spell checker is installed."
  (when-let ((checker (my/spell-checker-executable)))
    (setq ispell-program-name checker)
    (flyspell-mode 1)))

(defun my/enable-flyspell-prog-mode ()
  "Enable Flyspell for comments and strings when a checker is installed."
  (when-let ((checker (my/spell-checker-executable)))
    (setq ispell-program-name checker)
    (flyspell-prog-mode)))

(add-hook 'text-mode-hook #'my/enable-flyspell)
(add-hook 'org-mode-hook #'my/enable-flyspell)
(add-hook 'prog-mode-hook #'my/enable-flyspell-prog-mode)

(use-package flyspell-correct
  :defer t
  :commands flyspell-correct-at-point)

(use-package flyspell-correct-helm
  :defer t
  :after flyspell-correct
  :commands flyspell-correct-helm)

;;; Core Org

(defun my/org-mode-settings ()
  "Apply the small visual portion of the old Org configuration."
  (set-face-attribute 'org-level-1 nil :height 1.75 :foreground "#4f97d7")
  (set-face-attribute 'org-level-2 nil :height 1.5)
  (set-face-attribute 'org-level-3 nil :height 1.25)
  (set-face-attribute 'org-ellipsis nil :inherit 'default :box nil))

(use-package org
  :ensure nil
  :defer t
  :commands (org-agenda
             org-agenda-list
             org-capture
             org-store-link
             org-toggle-narrow-to-subtree)
  :hook (org-mode . my/org-mode-settings)
  :init
  (setq org-todo-keywords
        '((sequence "TODO(t)" "PROG(p/!)" "|" "DONE(d@/!)" "CANCELED(c@)"))
        org-src-preserve-indentation nil
        org-edit-src-content-indentation 0
        org-src-tab-acts-natively t
        org-blank-before-new-entry '((heading . t) (plain-list-item . t))
        org-auto-align-tags nil
        org-tags-column 0
        org-fold-catch-invisible-edits 'show-and-error
        org-special-ctrl-a/e t
        org-insert-heading-respect-content t
        org-hide-emphasis-markers t
        org-pretty-entities t
        org-agenda-tags-column 0
        org-ellipsis "…"
        org-fontify-done-headline nil
        org-fontify-todo-headline nil
        org-babel-python-command my/python-program)
  :config
  (require 'org-tempo)
  (org-babel-do-load-languages
   'org-babel-load-languages
   '((shell . t)
     (python . t)
     (C . t))))

;; Customizations made through Customize are generated separately and loaded
;; last, so this remains the only hand-authored Emacs configuration file.
(when (file-readable-p custom-file)
  (load custom-file nil 'nomessage))

(provide 'init)
;;; init.el ends here
