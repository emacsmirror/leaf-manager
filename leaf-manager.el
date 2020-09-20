;;; leaf-manager.el --- Configuration manager for leaf based init.el  -*- lexical-binding: t; -*-

;; Copyright (C) 2020  Naoya Yamashita

;; Author: Naoya Yamashita <conao3@gmail.com>
;; Version: 1.0.4
;; Keywords: convenience leaf
;; Package-Requires: ((emacs "26.1") (leaf "4.1") (leaf-convert "1.0") (ppp "2.1"))
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

;; Configuration manager for leaf based init.el


;;; Code:

(require 'package)
(require 'format-spec)
(require 'subr-x)
(require 'leaf)
(require 'leaf-convert)
(require 'ppp)

(defgroup leaf-manager nil
  "Configuration manager for leaf based init.el"
  :prefix "leaf-manager-"
  :group 'tools
  :link '(url-link :tag "Github" "https://github.com/conao3/leaf-manager.el"))

(defcustom leaf-manager-recursive-edit nil
  "If non-nil, use `recursive-edit' for `leaf-manager'."
  :group 'leaf-manager
  :type 'boolean)

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

%F

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
  `%F' The footer sexps are leaf-manager managed.
       They are expanded in (leaf *leaf-manager-footer ...)

Optional:
  `%f' The file feature name.  see `leaf-manager-template-feature-name'.

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

(defcustom leaf-manager-template-summary "My init.el auto-generated by leaf-manager"
  "The summary used in `leaf-manager-template'."
  :group 'leaf-manager
  :type 'string)

(defcustom leaf-manager-template-commentary ";; My init.el auto-generated by leaf-manager."
  "The commentary section used in `leaf-manager-template'."
  :group 'leaf-manager
  :type 'string)

(defcustom leaf-manager-template-copyright-from "2020"
  "The Copyright year from used in `leaf-manager-template'."
  :group 'leaf-manager
  :type 'string)

(defcustom leaf-manager-template-copyright-to nil
  "The Copyright year to used in `leaf-manager-template'.
When the value is a string it is used directly.
Nil means dynamic year value when output."
  :group 'leaf-manager
  :type '(choice string nil))

(defcustom leaf-manager-template-copyright-name user-full-name
  "The Copyright name used in `leaf-manager-template'."
  :group 'leaf-manager
  :type 'string)

(defcustom leaf-manager-template-author-name user-full-name
  "The author name used in `leaf-manager-template'."
  :group 'leaf-manager
  :type 'string)

(defcustom leaf-manager-template-author-email user-mail-address
  "The author email address used in `leaf-manager-template'."
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

(defcustom leaf-manager-edit-header-template
  ";;; leaf-manager
;; Packages %a

;; Load/Save file: %f
;; Loaded leaf block: %p
;; Auto-generated leaf block: %P
"
  "The format string used to leaf-manager edit buffer header.

The following %-sequences are supported:

Optional:
  `%a' The all specified package names.

  `%p' The loaded leaf package names.

  `%P' The auto-generated leaf package names.

  `%f' The string `leaf-manager-file'."
  :group 'leaf-manager
  :type 'string)

(defface leaf-manager-header-line
  '((t :inherit warning))
  "Face for section headings."
  :group 'leaf-manager)

(defvar leaf-manager--contents nil
  "`leaf-manager-file' contents cache.

Key is package name as symbol.
Value is alist
  - BODY is the leaf all value.")

(defvar leaf-manager-buffer nil
  "The buffer using `leaf-manager'.")

(defvar leaf-manager-edit-mode)


;;; Hash table function

(defun leaf-manager--hash-map (fn table)
  "Apply FN to each key-value pair of hash TABLE values."
  (when (hash-table-p table)
    (let (results)
      (maphash
       (lambda (key value)
         (push (funcall fn key value) results))
       table)
      results)))

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
    (setf (alist-get 'body (gethash 'leaf-manager table)) (nreverse sexps)))
  table)

(defun leaf-manager--contents ()
  "Read `leaf-manager-file' and put values into `leaf-manager--contents'."
  (let ((table (make-hash-table :test 'eq))
        sexps elm)
    (with-temp-buffer
      (insert-file-contents leaf-manager-file)
      (goto-char (point-min))
      (while (ignore-errors (setq elm (read (current-buffer))))
        (pcase elm
          (`(leaf leaf-manager . ,body)
           (setq table (leaf-manager--contents-1 table (leaf-normalize-plist body))))
          (`(prog1 'emacs . ,body)
           (dolist (e body)
             (push e sexps)))
          (`(provide . ,_)
           (ignore))
          (_
           (push elm sexps)))))
    (setf (alist-get 'body (gethash 'emacs table)) (nreverse sexps))
    (setq leaf-manager--contents table))
  leaf-manager--contents)

(defun leaf-manager--create-contents-string ()
  "Create string from `leaf-manager--contents'."
  (let ((ppp-tail-newline nil)
        (ppp-escape-newlines nil))
    (let* ((l-body  (alist-get 'body (gethash 'emacs leaf-manager--contents)))
           (lm-body (alist-get 'body (gethash 'leaf-manager leaf-manager--contents)))
           (lmf-body (alist-get 'body (gethash '*leaf-manager-footer leaf-manager--contents)))
           (L-body  (thread-last leaf-manager--contents
                      (leaf-manager--hash-keys)
                      (funcall (lambda (seq)
                                 (sort seq (lambda (a b)
                                             (string< (symbol-name a) (symbol-name b))))))
                      (cl-remove-if (lambda (elm) (memq elm '(emacs leaf-manager *leaf-manager-footer))))
                      (mapcar (lambda (elm)
                                `(leaf ,elm ,@(alist-get 'body (gethash elm leaf-manager--contents)))))))
           (l (ppp-sexp-to-string
               `(prog1 'emacs ,@l-body)))
           (L (ppp-sexp-to-string
               `(leaf leaf-manager ,@lm-body :config ,@(or L-body '(nil)))))
           (F (ppp-sexp-to-string
               `(leaf *leaf-manager-footer ,@lmf-body))))
      (format-spec
       leaf-manager-template
       `((?l . ,l)
         (?L . ,L)
         (?F . ,(if lmf-body F ""))
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

(defun leaf-manager--create-edit-buffer-header (arg)
  "Create header for leaf-manager edit buffer.
ARG is alist which contains info.
Now expect ARG has pkgs, existpkgs, noexistpkgs value."
  (let-alist arg
    (format-spec
     leaf-manager-edit-header-template
     `((?a . ,(mapconcat #'symbol-name .pkgs ", "))
       (?p . ,(mapconcat #'symbol-name .existpkgs ", "))
       (?P . ,(mapconcat #'symbol-name .noexistpkgs ", "))
       (?f . ,leaf-manager-file)))))

(defun leaf-manager--set-header-line-format (string)
  "Set the header-line using STRING.
Propertize STRING with the `leaf-manager-header-line'.  If the `face'
property of any part of STRING is already set, then that takes
precedence.  Also pad the left and right sides of STRING so that
it aligns with the text area.
see `magit-set-header-line-format'."
  (setq header-line-format
        (concat
         (propertize " " 'display '(space :align-to 0))
         string
         (propertize " " 'display
                     `(space :width
                             (+ left-fringe
                                left-margin
                                ,@(and (eq (car (window-current-scroll-bars))
                                           'left)
                                       '(scroll-bar)))))))
  (leaf-manager--add-face-text-property 0 (1- (length header-line-format))
                                        'leaf-manager-header-line t header-line-format))

(defun leaf-manager--add-face-text-property (beg end face &optional append object)
  "Like `add-face-text-property' but for `font-lock-face'.
Argument BEG END FACE APPEND OBJECT are same as `add-face-text-property'.
see `magit--add-face-text-property'."
  (cl-loop for pos = (next-single-property-change
                      beg 'font-lock-face object end)
           for current = (get-text-property beg 'font-lock-face object)
           for newface = (if (listp current)
                             (if append
                                 (append current (list face))
                               (cons face current))
                           (if append
                               (list current face)
                             (list face current)))
           do (progn (put-text-property beg pos 'font-lock-face newface object)
                     (setq beg pos))
           while (< beg end)))


;;; Main

(defun leaf-manager-load-contents ()
  "Load `leaf-manager-file' to `leaf-manager--contents'.
See also `leaf-manager--contents'."
  (interactive)
  (apply #'leaf-manager--contents)
  (when (called-interactively-p 'interactive)
    (message "leaf-manager: done!")))

(defun leaf-manager-write-contents (&optional force)
  "Write `leaf-manager--contents' to `leaf-manager-file'.
If FORCE is non-nil, write file if file exist."
  (interactive)
  (unless leaf-manager--contents
    (user-error "Manager haven't loaded init.el yet"))
  (unless (file-writable-p leaf-manager-file)
    (user-error "File (%s) cannot be written" leaf-manager-file))
  (when (and leaf-manager--contents
             (file-writable-p leaf-manager-file)
             (or (not (file-exists-p leaf-manager-file))
                 force
                 (yes-or-no-p (format "File exists (%s), overwrite? " leaf-manager-file))))
    (prog1 t
      (with-temp-file leaf-manager-file
        (insert (leaf-manager--create-contents-string))))))

;;;###autoload
(defun leaf-manager (pkgs)
  "Configuration manager for leaf based init.el.
Pop configure edit window for PKGS."
  (interactive
   ;; see `package-install'
   (progn
     ;; Initialize the package system to get the list of package
     ;; symbols for completion.
     (unless package--initialized
       (package-initialize t))
     (unless package-archive-contents
       (package-refresh-contents))
     (leaf-manager--contents)
     (list (let ((allpkg (thread-last
                             (append
                              '(nil)     ; final element
                              (mapcar (lambda (elm) (symbol-name (car elm))) package-archive-contents)
                              (mapcar #'symbol-name (leaf-manager--hash-keys leaf-manager--contents))
                              ;; see `load-library'
                              (locate-file-completion-table load-path (get-load-suffixes) "" nil t))
                           (mapcar (lambda (elm) (if (string-suffix-p "/" elm) nil elm)))
                           (delete-dups)))
                 elm lst)
             (while (setq elm (intern (completing-read "Package name (to finish, input `nil'): " allpkg)))
               (push elm lst))
             lst))))
  (when (or (or (not leaf-manager-buffer)
                (not (buffer-live-p leaf-manager-buffer)))
            (progn
              (pop-to-buffer leaf-manager-buffer)
              (yes-or-no-p "Now editing, discard? ")))
    (with-current-buffer (get-buffer-create "*leaf-manager*")
      (let* ((pkgs* (delete-dups (nreverse pkg)))
             (standard-output (current-buffer))
             (existpkgs   (cl-remove-if-not (lambda (elm) (gethash elm leaf-manager--contents)) pkgs*))
             (noexistpkgs (cl-remove-if (lambda (elm) (gethash elm leaf-manager--contents)) pkgs*)))
        (erase-buffer)
        (insert
         (leaf-manager--create-edit-buffer-header `((pkgs . ,pkgs*)
                                                    (existpkgs . ,existpkgs)
                                                    (noexistpkgs . ,noexistpkgs)))
         "\n")
        (ppp-sexp
         `(leaf leaf-manager
            ,@(alist-get 'body (gethash 'leaf-manager leaf-manager--contents))
            :config
            ,@(mapcar (lambda (elm)
                        `(leaf ,elm
                           ,@(if (memq elm existpkgs)
                                 (alist-get 'body (gethash elm leaf-manager--contents))
                               (cddr
                                (read
                                 (with-temp-buffer
                                   (leaf-convert-insert-template elm)
                                   (buffer-string)))))))
                      pkgs*)))
        (setq leaf-manager-buffer (current-buffer))
        (leaf-manager-edit-mode)))
    (if leaf-manager-recursive-edit
        (save-window-excursion
          (save-excursion
            (pop-to-buffer leaf-manager-buffer)
            (recursive-edit)))
      (pop-to-buffer leaf-manager-buffer))))


;;; Major-mode

(defun leaf-manager-edit-commit ()
  "Commit `leaf-manager-buffer' change to `leaf-manager-file'.
see `leaf-manager--contents'."
  (interactive)
  (unless (derived-mode-p 'leaf-manager-edit-mode)
    (user-error "It doesn't make sense to invoke this except in `leaf-manager-buffer'"))
  (goto-char (point-min))
  (let ((saved-contents leaf-manager--contents))
    (setq leaf-manager--contents nil)
    (let ((table (make-hash-table :test 'eq))   ; see `leaf-manager--contents'
          elm)
      (while (ignore-errors (setq elm (read (current-buffer))))
        (pcase elm
          (`(leaf leaf-manager . ,body)
           (setq table (leaf-manager--contents-1 table (leaf-normalize-plist body))))
          (_
           (user-error "Unknown sexp exists.  sexp: %s" elm))))
      (dolist (elm (leaf-manager--hash-keys table))
        (setf (alist-get 'body (gethash elm saved-contents))
              (alist-get 'body (gethash elm table))))
      (setq leaf-manager--contents saved-contents)))
  (leaf-manager-write-contents)
  (leaf-manager-edit-discard 'force)            ; kill buffer
  (message "Save done! %s" leaf-manager-file))

(defun leaf-manager-edit-discard (&optional force)
  "Discard `leaf-manager-buffer' change.
If FORCE is non-nil, discard change with no confirm."
  (interactive)
  (unless (derived-mode-p 'leaf-manager-edit-mode)
    (user-error "It doesn't make sense to invoke this except in `leaf-manager-buffer'"))
  (when (or force
            (yes-or-no-p "Discard changes? "))
    (kill-buffer leaf-manager-buffer)
    (when leaf-manager-recursive-edit
      (exit-recursive-edit))))

(defvar leaf-manager-edit-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-e") #'eval-buffer)
    (define-key map (kbd "C-c C-c") #'leaf-manager-edit-commit)
    (define-key map (kbd "C-c C-k") #'leaf-manager-edit-discard)
    map)
  "Keymap for `leaf-manager-edit-mode'.")

(define-derived-mode leaf-manager-edit-mode emacs-lisp-mode "Leaf-manager"
  "Major mode for editing leaf-manager buffer."
  (leaf-manager--set-header-line-format
   (substitute-command-keys
    "\
[\\<leaf-manager-edit-mode-map>\\[leaf-manager-edit-commit]] Commit to your init.el, \
[\\<leaf-manager-edit-mode-map>\\[eval-buffer]] Eval, \
[\\<leaf-manager-edit-mode-map>\\[leaf-manager-edit-discard]] Discard")))

(provide 'leaf-manager)

;; Local Variables:
;; indent-tabs-mode: nil
;; End:

;;; leaf-manager.el ends here
