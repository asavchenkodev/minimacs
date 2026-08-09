;;; init.el --- Small standalone Emacs configuration -*- lexical-binding: t; -*-

;; Start this profile without touching Spacemacs:
;; /Applications/Emacs.app/Contents/MacOS/Emacs \
;;   --init-directory=/Users/asv/projects/emacs-config

;;; Profile-local state

(require 'package)
(require 'seq)

(declare-function company-complete-common-or-cycle "company")
(declare-function company-complete-selection "company")
(declare-function company-select-next "company")
(declare-function company-select-previous "company")
(declare-function dired-find-alternate-file "dired")
(declare-function dired-up-directory "dired")
(declare-function flyspell-goto-next-error "flyspell")
(declare-function helm-autoresize-mode "helm")
(declare-function helm-do-ag-this-file "helm-ag")
(declare-function helm-execute-persistent-action "helm")
(declare-function helm-keyboard-quit "helm")
(declare-function helm-next-line "helm")
(declare-function helm-previous-page "helm")
(declare-function helm-previous-line "helm")
(declare-function helm-select-action "helm")
(declare-function helm-set-local-variable "helm")
(declare-function kill-compilation "compile")
(declare-function projectile-switch-project-by-name "projectile")
(declare-function recompile "compile")

(defvar helm-ag--default-target)

(defconst my/var-directory (expand-file-name "var/" user-emacs-directory))
(defconst my/backup-directory (expand-file-name "backups/" my/var-directory))
(defconst my/autosave-directory (expand-file-name "auto-save/" my/var-directory))

(dolist (directory (list my/var-directory
                         my/backup-directory
                         my/autosave-directory))
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
    company
    drag-stuff
    evil
    evil-collection
    flyspell-correct
    flyspell-correct-helm
    helm
    helm-projectile
    magit
    planet-theme
    projectile
    shell-pop
    vterm
    winum)
  "Packages installed from GNU ELPA, NonGNU ELPA, or MELPA.")

(defun my/install-missing-packages ()
  "Install missing packages, refreshing archives only when necessary."
  (let ((missing (seq-remove #'package-installed-p my/archive-packages)))
    (when missing
      (unless package-archive-contents
        (package-refresh-contents))
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

(require 'use-package)
(setq use-package-always-ensure nil)

;;; macOS environment and basic UI

(let ((homebrew-bin "/opt/homebrew/bin"))
  (add-to-list 'exec-path homebrew-bin)
  (unless (member homebrew-bin (parse-colon-path (getenv "PATH")))
    (setenv "PATH" (concat homebrew-bin path-separator (getenv "PATH")))))

(add-to-list 'default-frame-alist '(fullscreen . fullboth))
(add-to-list 'default-frame-alist '(font . "Menlo-12"))
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

;;; Editing defaults

(setq-default indent-tabs-mode nil
              show-trailing-whitespace t)

(setq split-height-threshold nil
      split-width-threshold 300
      compile-command ""
      compilation-scroll-output t
      compilation-skip-threshold 2
      dired-listing-switches "-alh"
      dired-use-ls-dired nil
      dired-kill-when-opening-new-dired-buffer t)

(setq c-default-style '((java-mode . "java")
                        (awk-mode . "awk")
                        (other . "stroustrup")))

(put 'dired-find-alternate-file 'disabled nil)
(with-eval-after-load 'dired
  (require 'dired-x))

;;; Small commands used by the leader map

(defun my/helm-search-current-file-empty ()
  "Search the current file with an initially empty Helm input."
  (interactive)
  (helm-do-ag-this-file ""))

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
                           (selected-window)))

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

;;; Home buffer

(defconst my/home-buffer-name "*home*")
(defconst my/home-items-limit 10)

(defvar-keymap my/home-mode-map
  :parent special-mode-map
  "<backtab>" #'backward-button
  "TAB" #'forward-button
  "g" #'my/home-refresh
  "q" #'bury-buffer)

(define-derived-mode my/home-mode special-mode "Home"
  "Major mode for the lightweight startup page."
  (setq-local show-trailing-whitespace nil))

(defun my/home-read-data (file)
  "Read and return the first Lisp value in FILE, or nil."
  (when (file-readable-p file)
    (condition-case nil
        (with-temp-buffer
          (insert-file-contents file)
          (goto-char (point-min))
          (read (current-buffer)))
      (error nil))))

(defun my/home-recent-project-roots ()
  "Return project roots inferred from `recentf-list'."
  (delq nil
        (mapcar
         (lambda (file)
           (unless (file-remote-p file)
             (let ((directory (file-name-directory (expand-file-name file))))
               (when (file-directory-p directory)
                 (or (locate-dominating-file directory ".projectile")
                     (locate-dominating-file directory ".git"))))))
         recentf-list)))

(defun my/home-project-roots ()
  "Return recently used project roots without loading Projectile."
  (let* ((projectile-data
          (my/home-read-data
           (expand-file-name "projectile-bookmarks.eld" my/var-directory)))
         (project-data (my/home-read-data project-list-file))
         (project-roots
          (mapcar (lambda (entry)
                    (if (stringp entry) entry (car-safe entry)))
                  project-data))
         (roots (delete-dups
                 (append projectile-data
                         (my/home-recent-project-roots)
                         project-roots))))
    (seq-take
     (seq-filter
      (lambda (root)
        (let ((expanded (and (stringp root) (expand-file-name root))))
          (and expanded
               (not (file-remote-p expanded))
               (file-directory-p expanded)
               (not (file-in-directory-p expanded package-user-dir)))))
      roots)
     my/home-items-limit)))

(defun my/home-file-label (file)
  "Return the home-page label for FILE."
  (let ((expanded (expand-file-name file)))
    (format "%-28s %s"
            (file-name-nondirectory expanded)
            (abbreviate-file-name (file-name-directory expanded)))))

(defun my/home-project-label (project)
  "Return the home-page label for PROJECT."
  (let ((expanded (directory-file-name (expand-file-name project))))
    (format "%-28s %s"
            (file-name-nondirectory expanded)
            (abbreviate-file-name expanded))))

(defun my/home-open-file (button)
  "Visit the file stored in BUTTON."
  (find-file (button-get button 'my/path)))

(defun my/home-open-project (button)
  "Switch to the project stored in BUTTON."
  (require 'projectile)
  (projectile-switch-project-by-name (button-get button 'my/path)))

(defun my/home-insert-section (title items label-function action)
  "Insert a TITLE section of ITEMS using LABEL-FUNCTION and ACTION."
  (insert (propertize title 'face '(:inherit font-lock-keyword-face
                                    :weight bold :height 1.2))
          "\n\n")
  (if items
      (dolist (item items)
        (insert "  ")
        (insert-text-button (funcall label-function item)
                            'action action
                            'my/path item
                            'follow-link t
                            'help-echo (expand-file-name item)
                            'face 'link)
        (insert "\n"))
    (insert (propertize "  Nothing recorded yet.\n" 'face 'shadow)))
  (insert "\n"))

(defun my/home-refresh ()
  "Refresh the lightweight home buffer."
  (interactive)
  (let ((buffer (get-buffer-create my/home-buffer-name)))
    (with-current-buffer buffer
      (my/home-mode)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert "\n    "
                (propertize "EMACS" 'face '(:inherit font-lock-function-name-face
                                             :weight bold :height 2.0))
                "\n    A small, fast standalone profile\n\n")
        (my/home-insert-section
         "Recent files"
         (seq-take recentf-list my/home-items-limit)
         #'my/home-file-label #'my/home-open-file)
        (my/home-insert-section
         "Projects"
         (my/home-project-roots)
         #'my/home-project-label #'my/home-open-project)
        (insert (propertize
                 "  RET open    TAB next    g refresh    q close\n"
                 'face 'shadow))
        (goto-char (point-min))
        (ignore-errors (forward-button 1))
        (set-buffer-modified-p nil)))
    buffer))

(defun my/home ()
  "Show and return the lightweight home buffer."
  (interactive)
  (let ((buffer (my/home-refresh)))
    (when (called-interactively-p 'interactive)
      (switch-to-buffer buffer))
    buffer))

(setq initial-buffer-choice #'my/home)

;;; Native leader keymaps

(defvar-keymap my/leader-buffer-map
  :doc "Buffer commands."
  :name "buffers"
  "b" #'helm-mini
  "h" #'my/home)

(defvar-keymap my/leader-file-map
  :doc "File commands."
  :name "files"
  "f" #'helm-find-files
  "j" #'dired-jump
  "s" #'save-buffer)

(defvar-keymap my/leader-project-map
  :doc "Project commands."
  :name "projects"
  "b" #'helm-projectile-switch-to-buffer
  "c" #'projectile-compile-project
  "d" #'helm-projectile-find-dir
  "f" #'helm-projectile-find-file
  "F" #'helm-projectile-find-file-dwim
  "/" #'helm-do-ag-project-root
  "p" #'helm-projectile-switch-project)

(defvar-keymap my/leader-search-ag-map
  :doc "Spacemacs-compatible helm-ag aliases."
  :name "helm-ag"
  "a" #'helm-do-ag-this-file
  "d" #'helm-do-ag
  "p" #'helm-do-ag-project-root)

(defvar-keymap my/leader-search-map
  :doc "Search commands."
  :name "search"
  "P" #'helm-do-ag-project-root
  "S" #'helm-do-ag-this-file
  "a" my/leader-search-ag-map
  "d" #'helm-do-ag
  "p" #'helm-do-ag-project-root
  "s" #'my/helm-search-current-file-empty)

(defvar-keymap my/leader-git-map
  :doc "Git commands."
  :name "git"
  "s" #'magit-status)

(defvar-keymap my/leader-compilation-map
  :doc "Compilation commands."
  :name "compile"
  "N" #'previous-error
  "c" #'compile
  "k" #'kill-compilation
  "n" #'next-error
  "r" #'recompile)

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
  "1" #'winum-select-window-1
  "2" #'winum-select-window-2
  "3" #'winum-select-window-3
  "4" #'winum-select-window-4
  "5" #'winum-select-window-5
  "6" #'winum-select-window-6
  "7" #'winum-select-window-7
  "8" #'winum-select-window-8
  "9" #'winum-select-window-9
  "SPC" #'helm-M-x
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
  "n" my/leader-narrow-map
  "p" my/leader-project-map
  "s" my/leader-search-map
  "t" my/leader-toggle-map
  "w" my/leader-window-map)

;; `defvar-keymap' intentionally preserves an existing value.  Set additions
;; explicitly too, so evaluating init.el in a running Emacs updates the map.
(keymap-set my/leader-map "*" #'helm-do-ag-project-root)
(keymap-set my/leader-map "b h" #'my/home)
(keymap-set my/leader-map "f s" #'save-buffer)
(keymap-set my/leader-map "s s" #'my/helm-search-current-file-empty)
(keymap-set my/leader-map "s S" #'helm-do-ag-this-file)

;;; Evil and key discovery

(use-package evil
  :demand t
  :config
  (evil-mode 1)
  (evil-set-initial-state 'my/home-mode 'motion)
  (evil-define-key 'motion my/home-mode-map
    (kbd "<backtab>") #'backward-button
    (kbd "TAB") #'forward-button
    (kbd "g") #'my/home-refresh
    (kbd "q") #'bury-buffer)
  (evil-define-key '(normal motion visual) 'global
    (kbd "C-u") #'evil-scroll-up)
  (evil-define-key '(normal motion visual) 'global (kbd "SPC") my/leader-map)
  (evil-define-key '(insert emacs) 'global (kbd "M-m") my/leader-map))

(defun my/evil-collection-local-bindings (mode _maps)
  "Apply personal bindings after Evil Collection configures MODE."
  (when (eq mode 'dired)
    (evil-define-key 'normal dired-mode-map
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
    "S" "spelling"
    "a" "applications"
    "b" "buffers"
    "c" "compile"
    "d" "custom"
    "f" "files"
    "g" "git"
    "n" "narrow"
    "p" "projects"
    "s" "search"
    "t" "toggles"
    "w" "windows"))

(winner-mode 1)

(use-package winum
  :demand t
  :custom
  (winum-auto-assign-0-to-minibuffer nil)
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
  :commands (helm-M-x helm-mini helm-buffers-list helm-find-files)
  :bind (("M-x" . helm-M-x)
         ("C-x C-f" . helm-find-files)
         ("C-x b" . helm-buffers-list))
  :custom
  ;; Helm-AG results follow the selection: moving with C-j/C-k previews the
  ;; match in the original window and keeps the current occurrence highlighted.
  (helm-follow-mode-persistent t)
  (helm-follow-input-idle-delay 0.1)
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
  ;; SPC SPC shows recent commands first, in actual recency order, followed by
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
  (keymap-set helm-map "C-j" #'helm-next-line)
  (keymap-set helm-map "C-k" #'helm-previous-line)
  (keymap-set helm-map "C-u" #'helm-previous-page)
  (evil-define-key 'normal helm-map (kbd "C-u") #'helm-previous-page)
  (keymap-set helm-map "TAB" #'helm-execute-persistent-action)
  (keymap-set helm-map "<tab>" #'helm-execute-persistent-action)
  (keymap-set helm-map "C-z" #'helm-select-action)
  (keymap-set helm-map "<escape>" #'helm-keyboard-quit)
  (helm-autoresize-mode 1))

(use-package projectile
  :defer t
  :commands (projectile-compile-project projectile-project-root)
  :init
  (setq projectile-completion-system 'helm
        projectile-indexing-method 'hybrid
        projectile-cache-file (expand-file-name "projectile-cache.el" my/var-directory)
        projectile-known-projects-file
        (expand-file-name "projectile-bookmarks.eld" my/var-directory)))

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
  (helm-projectile-mode 1))

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
  (unless (advice-member-p #'my/helm-ag-omit-duplicate-current-file
                           'helm-ag--construct-command)
    (advice-add 'helm-ag--construct-command :around
                #'my/helm-ag-omit-duplicate-current-file)))

;;; Magit, compilation, Dired, and terminal

(use-package magit
  :defer t
  :commands magit-status)

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
        vterm-always-compile-module t))

;;; Completion and language modes

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

(setq python-shell-interpreter "/opt/homebrew/bin/python3"
      python-indent-offset 4)

(defun my/python-mode-settings ()
  "Use the Python layout from the previous configuration."
  (setq-local fill-column 79
              tab-width 4))

(add-hook 'python-mode-hook #'my/python-mode-settings)

;;; Spelling

(setq ispell-program-name "/opt/homebrew/bin/hunspell"
      ispell-dictionary "en_US"
      ispell-personal-dictionary (expand-file-name "personal-dictionary" my/var-directory))
(setenv "DICPATH" (expand-file-name "~/Library/Spelling"))

(add-hook 'text-mode-hook #'flyspell-mode)
(add-hook 'org-mode-hook #'flyspell-mode)
(add-hook 'prog-mode-hook #'flyspell-prog-mode)

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
        org-babel-python-command "/opt/homebrew/bin/python3")
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
