;;; elisp-demos.el --- Elisp API Demos               -*- lexical-binding: t; -*-

;; Copyright (C) 2018  Xu Chunyang

;; Author: Xu Chunyang <mail@xuchunyang.me>
;; Homepage: https://github.com/xuchunyang/elisp-demos
;; Keywords: help, lisp
;; Version: 0.1
;; Package-Requires: ((emacs "25.1"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Elisp API Demos

;;; Code:

(require 'subr-x)

(defconst elisp-demos--load-dir (file-name-directory
                                 (or load-file-name buffer-file-name)))

(defconst elisp-demos--elisp-demos.org (expand-file-name
                                        "elisp-demos.org"
                                        elisp-demos--load-dir))

(defun elisp-demos--search (symbol)
  (with-temp-buffer
    (insert-file-contents elisp-demos--elisp-demos.org)
    (goto-char (point-min))
    (when (re-search-forward (format "^\\* %s$" (regexp-quote (symbol-name symbol))) nil t)
      (let (beg end)
        (forward-line 1)
        (setq beg (point))
        (if (re-search-forward "^\\*" nil t)
            (setq end (line-beginning-position))
          (setq end (point-max)))
        (string-trim (buffer-substring-no-properties beg end))))))

(defun elisp-demos--syntax-highlight (orgsrc)
  (with-temp-buffer
    (insert orgsrc)
    (delay-mode-hooks (org-mode))
    (font-lock-ensure)
    (buffer-string)))

(defun elisp-demos--symbols ()
  (with-temp-buffer
    (insert-file-contents elisp-demos--elisp-demos.org)
    (goto-char (point-min))
    (let (symbols)
      (while (re-search-forward "^\\* \\(.+\\)$" nil t)
        (push (intern (match-string-no-properties 1)) symbols))
      (nreverse symbols))))

(declare-function org-show-entry "org")

(defun elisp-demos-find-demo (symbol)
  "Find the demo of the SYMBOL."
  (interactive
   (let* ((sym-here (symbol-at-point))
          (symbols (elisp-demos--symbols))
          (default-val (and sym-here
                            (memq sym-here symbols)
                            (symbol-name sym-here)))
          (prompt (if default-val
                      (format "Find demo (default: %s): " default-val)
                    "Find demo: ")))
     (list (read (completing-read prompt
                                  (mapcar #'symbol-name symbols)
                                  nil t nil nil default-val)))))
  (when symbol
    (find-file elisp-demos--elisp-demos.org)
    (goto-char (point-min))
    (and (re-search-forward
          (format "^\\* %s$" (regexp-quote (symbol-name symbol))))
         (goto-char (line-beginning-position))
         (org-show-entry))
    t))

;;; * C-h f (`describe-function')

(defun elisp-demos-help-find-demo-at-point ()
  "Find the demo at point."
  (interactive)
  (let ((offset (- (point) (get-text-property (point) 'start))))
    (and (elisp-demos-find-demo (get-text-property (point) 'symbol))
         ;; Skip heading and an empty line
         (forward-line 2)
         (forward-char offset))))

(defvar elisp-demos-help-keymap
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") #'elisp-demos-help-find-demo-at-point)
    map))

(defun elisp-demos--describe-function (function)
  (when-let* ((src (elisp-demos--search function))
              (buf (get-buffer "*Help*")))
    (with-current-buffer buf
      (save-excursion
        (goto-char (point-max))
        (re-search-backward
         (rx line-start (or "[back]" "[forward]"))
         nil t)
        (let ((inhibit-read-only t))
          (when (eobp) (insert "\n"))
          (insert
           (propertize (elisp-demos--syntax-highlight src)
                       'start (point)
                       'symbol function
                       'keymap elisp-demos-help-keymap)
           "\n")
          (unless (eobp) (insert "\n")))))))

;;; * helpful.el - https://github.com/Wilfred/helpful

(defvar helpful--sym)
(declare-function helpful--heading "helpful")

(defun elisp-demos--helpful-update ()
  (when-let* ((src (elisp-demos--search helpful--sym)))
    (save-excursion
      (goto-char (point-min))
      (when (re-search-forward "^References$")
        (goto-char (line-beginning-position))
        (let ((inhibit-read-only t))
          (insert
           (helpful--heading "Demos")
           (propertize (elisp-demos--syntax-highlight src)
                       'start (point)
                       'symbol helpful--sym
                       'keymap elisp-demos-help-keymap)
           "\n\n"))))))

;;;###autoload
(define-minor-mode elisp-demos-help-mode
  "Inject Elisp demos into *Help*."
  :global t
  :require 'elisp-demos
  (if elisp-demos-help-mode
      (progn (advice-add 'describe-function :after #'elisp-demos--describe-function)
             (advice-add 'helpful-update :after #'elisp-demos--helpful-update))
    (advice-remove 'describe-function #'elisp-demos--describe-function)
    (advice-remove 'helpful-update #'elisp-demos--helpful-update)))

(provide 'elisp-demos)
;;; elisp-demos.el ends here
