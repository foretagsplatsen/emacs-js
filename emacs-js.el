;;; emacs-js.el --- JS-mode Setup                -*- lexical-binding: t; -*-

;; Copyright (C) 2016  Nicolas Petton

;; Author: Nicolas Petton <nicolas@petton.fr>
;; Keywords: convenience javascript
;; Version: 0.1
;; GIT: https://github.com/foretagsplatsen/emacs-js
;; Package-Requires: ((emacs "24.4") (js2-mode "20160623") (js2-refactor "0.7.1") (amd-mode "1.1") (tern "0.19.0") (widgetjs "20160719") (company-tern "0.2.0") (flycheck "28") (xref-js2 "1.3"))
;; Created: 20 Apr 2016

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This file is a helper for setting up a good environment for editing JS files.
;; Some of of the settings below are specific to Företagsplatsen, but most of it
;; should be generic and reusable.

;;; Code:

(require 'js2-mode)
(require 'js2-refactor)
(require 'amd-mode)
(require 'eslintd-fix)
(require 'tern)
(require 'widgetjs)
(require 'company-tern)
(require 'flycheck)
(require 'xref-js2)
(require 'yasnippet)
(require 'indium)

(if (executable-find "eslint_d")
    (setq flycheck-javascript-eslint-executable "eslint_d")
  (warn "emacs-js: You might want to install eslint_d: sudo npm install -g eslint_d."))

(add-hook 'js-mode-hook #'setup-js-buffer)

(add-to-list 'auto-mode-alist '("\\.js\\'" . js2-mode))

(defun setup-js-buffer ()
  (when (and (derived-mode-p 'js-mode) (not (derived-mode-p 'json-mode)))
    (company-mode 1)
    (tern-mode 1)
    ;; When the buffer is not visiting a file, eslint systematically fails
    (if buffer-file-name
	(flycheck-mode 1)
      (flycheck-mode -1))
    (js2-minor-mode 1)
    (js2-refactor-mode 1)
    (js2-imenu-extras-mode)
    (indium-interaction-mode 1)
    (amd-mode 1)
    (widgetjs-mode 1))

  ;; add eslintd-fix support
  (eslintd-fix-mode)

  ;; add xref-js2 support
  (add-hook 'xref-backend-functions #'xref-js2-xref-backend nil t)

  ;; we use tabs in JS files
  (setq tab-width 4)
  (setq indent-tabs-mode t)
  (setq js-switch-indent-offset 4)

  (setq js2-global-externs '("define" "require" "app" "fetch"))
  (setq js2-include-node-externs t)
  (setq js2-pretty-multiline-declarations nil)
  (setq js2-strict-trailing-comma-warning nil)

  (yas-minor-mode +1)

  (set (make-local-variable 'company-dabbrev-ignore-case) nil)
  (set (make-local-variable 'company-dabbrev-downcase) nil))

(defun add-jasmine-externs ()
  "Add jasmine global names to `js2-additional-externs'."
  (mapc (lambda (extern) (add-to-list 'js2-additional-externs extern))
        '("jasmine"
          "describe" "fdescribe" "it" "fit"
          "expect" "spyOn"
          "beforeEach" "afterEach" "beforeAll" "afterAll")))

(defun setup-js2-init ()
  "Hook run when js2 is initializing a buffer."
  (when (and buffer-file-name
             (string-match-p "-tests?.js$" buffer-file-name))
    (add-jasmine-externs)))

(add-hook 'js2-init-hook #'setup-js2-init)

;; We have JS files in Scripts directories, ignore that
(add-to-list 'xref-js2-ignored-dirs "Scripts")

;; Also ignore some other files
(dolist (file '("require.js" "highcharts.js" "highcharts.src.js" "bootstrap.js" "Gruntfile.js" "moment.js" "moment-with-locales.js"))
  (add-to-list 'xref-js2-ignored-files file))

;; tern will override js2r keybindings...
(define-key tern-mode-keymap (kbd "C-c C-r") nil)

;; ... and xref.
(define-key tern-mode-keymap (kbd "M-.") nil)
(define-key tern-mode-keymap (kbd "M-,") nil)

(js2r-add-keybindings-with-prefix "C-c C-r")
(setq js2r-always-insert-parens-around-arrow-function-params t)
(setq js2r-prefer-let-over-var t)

(define-key js-mode-map (kbd "M-.") nil)
(define-key js-mode-map (kbd "C-c C-j") nil)

(define-key amd-mode-map (kbd "C-c C-a") #'amd-initialize-makey-group)
(setq amd-use-relative-file-name t)

;; eslint parser executable can be overridden in some projects but marked as
;; risky, so silence that.
(put 'flycheck-javascript-eslint-executable 'risky-local-variable nil)

(defun kill-tern-process ()
  "Kill the tern process if any.
The process will be restarted.  This is useful if tern becomes
unreachable."
  (interactive)
  (delete-process "Tern"))

(add-to-list 'company-backends 'company-tern)

;; paredit-like commands for JS
(define-key js-mode-map (kbd "<C-right>") #'js2r-forward-slurp)
(define-key js-mode-map (kbd "<C-left>") #'js2r-forward-barf)
(define-key js-mode-map (kbd "C-k") #'js2r-kill)
(define-key js-mode-map (kbd "M-S") #'js-smart-split)

;;; Convenience functions

(defun js-smart-split ()
  "Split the string or var declaration at point."
  (interactive)
  (let ((node (js2-node-at-point)))
    (cond ((js2-string-node-p node) (js2r-split-string))
          (t (js2r-split-var-declaration)))))

(defun mdn-search (searchString)
  "Open a browser on the MDN page for SEARCHSTRING."
  (interactive (list (read-string "Search: " (thing-at-point 'symbol))))
  (browse-url (format "https://developer.mozilla.org/en-US/search?q=%s&topic=js" searchString)))

(define-key js-mode-map (kbd "C-c m") #'mdn-search)

(add-to-list 'yas-snippet-dirs
             (expand-file-name "snippets"
                               (file-name-directory
                                (or load-file-name buffer-file-name)))
             t)
(yas-reload-all)

(provide 'emacs-js)
;;; emacs-js.el ends here
