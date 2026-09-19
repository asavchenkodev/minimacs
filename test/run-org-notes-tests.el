;;; run-org-notes-tests.el --- Batch runner for Org Notes tests -*- lexical-binding: t; -*-

(setq load-prefer-newer t)
(add-to-list 'load-path
             (expand-file-name "../lisp" (file-name-directory load-file-name)))
(add-to-list 'load-path (file-name-directory load-file-name))
(require 'org-notes-test)
(ert-run-tests-batch-and-exit)

;;; run-org-notes-tests.el ends here
