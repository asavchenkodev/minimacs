;;; early-init.el --- Early startup settings -*- lexical-binding: t; -*-

;; Prefer init.el whenever it is newer than a leftover byte-compiled file.
;; Without this, Emacs loads a stale init.elc and silently ignores source edits.
(setq load-prefer-newer t)

;; justl supports optional vterm and eat integrations without depending on
;; either package.  Its source therefore produces undefined-function warnings
;; when Emacs JIT-compiles it in a clean subprocess.  Keep using its portable
;; byte-compiled file instead of displaying those harmless warnings at startup.
(with-eval-after-load 'comp-run
  (add-to-list 'native-comp-jit-compilation-deny-list
               "/justl-[^/]+/justl\\.el\\'"))

;;; early-init.el ends here
