;;; early-init.el --- Early startup settings -*- lexical-binding: t; -*-

;; Prefer init.el whenever it is newer than a leftover byte-compiled file.
;; Without this, Emacs loads a stale init.elc and silently ignores source edits.
(setq load-prefer-newer t)

;;; early-init.el ends here
