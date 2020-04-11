;;; leaf-manager.el --- Configure manager for leaf based init.el  -*- lexical-binding: t; -*-

;; Copyright (C) 2020  Naoya Yamashita

;; Author: Naoya Yamashita <conao3@gmail.com>
;; Version: 0.0.1
;; Keywords: convenience leaf
;; Package-Requires: ((emacs "25.1") (leaf "4.1") (ppp "2.1"))
;; URL: https://github.com/conao3/leaf-manager.el

;; This program is free software: you can redistribute it and/or modify
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

;; Interactive folding Elisp code using :tag leaf keyword.


;;; Code:

(require 'format-spec)
(require 'subr-x)
(require 'leaf)
(require 'ppp)

(defgroup leaf-manager nil
  "Configure manager for leaf based init.el"
  :prefix "leaf-manager-"
  :group 'tools
  :link '(url-link :tag "Github" "https://github.com/conao3/leaf-manager.el"))

(defcustom leaf-manager-file (locate-user-emacs-file "init.el")
  "Manage target user init.el file path."
  :group 'leaf-manager
  :type 'string)

(defcustom leaf-manager-template
  ";;; %f.el --- %s  -*- lexical-binding: t; -*-

;; Copyright (C) %y-%Y %n

;; Author: %N <%M>

%I

;;; Commentary:

%S

;;; Code:

%l

%L

(provide '%f)

;; Local Variables:
%v
;; End:

;;; %f.el ends here
"
  "The format string used to output file.

The following %-sequences are supported:

Must:
  `%l' The sexps are not leaf-manager managed.
       They are expanded in (prog1 'Emacs ...).
  `%L' The sexps are leaf-manager managed.
       They are expanded in (leaf leaf-manager ...)

Optional:
  `%f' The file feature name.  see `leaf-manager-templater-feature-name'.

  `%s' The init.el summary.  see `leaf-manager-template-summary'.

  `%S' The init.el commentary.  see `leaf-manager-template-commentary'.

  `%y' The Copyright year from.  see `leaf-manager-template-copyright-from'.

  `%Y' The Copyright year to.  see `leaf-manager-template-copyright-to'.

  `%n' The init.el Copyright name.  see `leaf-manager-template-copyright-name'.

  `%N' The init.el author name.  see `leaf-manager-template-author-name'.

  `%M' The author mail address.  see `leaf-manager-template-author-email'.

  `%I' The License header.  see `leaf-manager-template-license'.

  `%v' The local variables.  see `leaf-manager-template-local-variables'."
  :group 'leaf-manager
  :type 'string)

(defcustom leaf-manager-template-feature-name "init"
  "The feature name used in `leaf-manager-template'."
  :group 'leaf-manager
  :type 'string)

(defcustom leaf-manager-template-summary "My init.el autogenerated by leaf-manager"
  "The summary used in `leaf-manager-template'."
  :group 'leaf-manager
  :type 'string)

(defcustom leaf-manager-template-commentary ";; My init.el autogenerated by leaf-manager."
  "The commentary section used in `leaf-manager-template'."
  :group 'leaf-manager
  :type 'string)

(defcustom leaf-manager-template-copyright-from "2020"
  "The Copyright year from used in `leaf-manager-template'."
  :group 'leaf-manager
  :type 'string)

(defcustom leaf-manager-template-copyright-to nil
  "The Copyright year to used in `leaf-manager-template'.
Value as string use straightly.
Nil means dynamic year value when output."
  :group 'leaf-manager
  :type 'sexp)

(defcustom leaf-manager-template-copyright-name user-full-name
  "The Copyright name used in `leaf-manager-template'."
  :group 'leaf-manager
  :type 'string)

(defcustom leaf-manager-template-author-name user-full-name
  "The author name used in `leaf-manager-template'."
  :group 'leaf-manager
  :type 'string)

(defcustom leaf-manager-template-author-email user-mail-address
  "The author email used in `leaf-manager-template'."
  :group 'leaf-manager
  :type 'string)

(defcustom leaf-manager-template-license
  ";; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>."
  "The License header used in `leaf-manager-template'."
  :group 'leaf-manager
  :type 'string)

(defcustom leaf-manager-template-local-variables
  ";; indent-tabs-mode: nil
;; buffer-read-only: t"
  "The local variables specification used in `leaf-manager-template'."
  :group 'leaf-manager
  :type 'string)

(defvar leaf-manager--contents nil
  "`leaf-manager-file' contents cache.

Key is package name as symbol.
Value is alist
  - BODY is the leaf all value.")

(defvar leaf-manager--contents-dirty nil
  "The flag whether `leaf-manger--contents' is dirty.
Dirty state is loaded and editted, but not saved state.")


;;; Hash table function

(defun leaf-manager--hash-map (fn table)
  "Apply FN to each key-value pair of hash TABLE values."
  (let (results)
    (maphash
     (lambda (key value)
       (push (funcall fn key value) results))
     table)
    results))

(defun leaf-manager--hash-keys (table)
  "Return a list of all the keys in TABLE."
  (leaf-manager--hash-map (lambda (key _value) key) table))


;;; Function

(defun leaf-manager--contents-1 (table body)
  "Internal function for `leaf-manager--contents'.
Process leaf-manager BODY arguments into TABLE."
  (let (sexps)
    (cl-loop for (key val) on body by #'cddr
             do
             (if (not (eq key :config))
                 (progn
                   (push key sexps)
                   (dolist (v val)
                     (push v sexps)))
               (dolist (e val)
                 (pcase e
                   (`(leaf ,(and (pred symbolp) pkg) . ,body*)
                    (when (gethash pkg table)
                      (error "Duplicate leaf block.  package: %s" pkg))
                    (setf (alist-get 'body (gethash pkg table)) body*))
                   (_
                    (error "Leaf-manager :config includes unknown sexp.  sexp: %s" e))))))
    (setf (alist-get 'body (gethash 'leaf-manager table)) (nreverse sexps))))

(defun leaf-manager--contents (&optional force)
  "Read `leaf-manager-file' and put values into `leaf-manager--contents'.
If FORCE is non-nil, read file even if cache is avairable."
  (when (or (not leaf-manager--contents)
            (not leaf-manager--contents-dirty)
            force
            (yes-or-no-p "Cache variable is not saved, discard and reload? "))
    (let ((table (make-hash-table :test 'eq))
          sexps elm)
      (with-temp-buffer
        (insert-file-contents leaf-manager-file)
        (goto-char (point-min))
        (while (ignore-errors (setq elm (read (current-buffer))))
          (pcase elm
            (`(leaf leaf-manager . ,body)
             (leaf-manager--contents-1 table (leaf-normalize-plist body)))
            (`(prog1 'emacs . ,body)
             (dolist (e body)
               (push e sexps)))
            (`(provide . ,_)
             (ignore))
            (_
             (push elm sexps)))))
      (setf (alist-get 'body (gethash 'emacs table)) (nreverse sexps))
      (setq leaf-manager--contents table)
      (setq leaf-manager--contents-dirty nil)))
  leaf-manager--contents)

(defun leaf-manager--create-contents-string ()
  "Create string from `leaf-manager--contents'."
  (let ((ppp-tail-newline nil)
        (ppp-escape-newlines nil))
    (let* ((l-body  (alist-get 'body (gethash 'emacs leaf-manager--contents)))
           (lm-body (alist-get 'body (gethash 'leaf-manager leaf-manager--contents)))
           (L-body  (thread-last leaf-manager--contents
                      (leaf-manager--hash-keys)
                      (funcall (lambda (seq)
                                 (sort seq (lambda (a b)
                                             (string< (symbol-name a) (symbol-name b))))))
                      (cl-remove-if (lambda (elm) (memq elm '(emacs leaf-manager))))
                      (mapcar (lambda (elm)
                                `(leaf ,elm ,@(alist-get 'body (gethash elm leaf-manager--contents)))))))
           (l (ppp-sexp-to-string
               `(prog1 'emacs ,@l-body)))
           (L (ppp-sexp-to-string
               `(leaf leaf-manager ,@lm-body :config ,@(or L-body '(nil))))))
      (format-spec
       leaf-manager-template
       `((?l . ,l)
         (?L . ,L)
         (?f . ,leaf-manager-template-feature-name)
         (?s . ,leaf-manager-template-summary)
         (?S . ,leaf-manager-template-commentary)
         (?y . ,leaf-manager-template-copyright-from)
         (?Y . ,(or leaf-manager-template-copyright-to
                    (format-time-string "%Y")))
         (?n . ,leaf-manager-template-copyright-name)
         (?N . ,leaf-manager-template-author-name)
         (?M . ,leaf-manager-template-author-email)
         (?I . ,leaf-manager-template-license)
         (?v . ,leaf-manager-template-local-variables))))))

(defun leaf-manager-load-contents (&optional force)
  "Load `leaf-manager-file' to `leaf-manager--contents'.
If FORCE is non-nil, load file if `leaf-manager-contents' is dirty state.
See also `leaf-manager--contents'."
  (interactive)
  (apply #'leaf-manager--contents force))

(defun leaf-manager-write-contents (&optional force)
  "Write `leaf-manager--contents' to `leaf-manager-file'.
If FORCE is non-nil, write file if file exist."
  (interactive)
  (when (called-interactively-p 'interactive)
    (unless leaf-manager--contents
      (user-error "Manager haven't loaded init.el yet"))
    (unless leaf-manager--contents-dirty
      (user-error "No need to write, as it has not been edited yet"))
    (unless (file-writable-p leaf-manager-file)
      (user-error "File (%s) cannot writable" leaf-manager-file)))
  (when (and leaf-manager--contents
             leaf-manager--contents-dirty
             (file-writable-p leaf-manager-file)
             (or (not (file-exists-p leaf-manager-file))
                 force
                 (yes-or-no-p (format "File exist (%s), replace? " leaf-manager-file))))
    (prog1 t
      (with-temp-file leaf-manager-file
        (insert (leaf-manager--create-contents-string)))
      (setq leaf-manager--contents-dirty nil)
      (when (called-interactively-p 'interactive)
        (message "leaf-manager: done!")))))


;;; Main

(defun leaf-manager (spec)
  "Configure manager for leaf based init.el.
Pop configure edit window for SPEC."
  spec)

(provide 'leaf-manager)

;; Local Variables:
;; indent-tabs-mode: nil
;; End:

;;; leaf-manager.el ends here
