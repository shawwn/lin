(eval-when-compile
  (require 'cl))

(defgroup lin nil
  "Lisp indentation and highlighting."
  :prefix "lin-"
  :group 'applications)

(defgroup lin-faces nil
  "Faces for Lisp highlighting"
  :group 'lin
  :group 'faces
  :link '(custom-group-link "lin")
  :prefix "lin-")

(defface lin-paren-face
  '((((background light)) (:foreground "#2aa198" :weight bold))
    (((background dark)) (:foreground "#2aa198" :weight bold)))
  "Face to highlight paren characters in,
i.e. `(' and `)'"
  :group 'lin-faces)

(defface lin-bracket-face
  '((((background light)) (:foreground "#cb4b16"))
    (((background dark)) (:foreground "#cb4b16")))
  "Face to highlight bracket characters in,
i.e. `[' and `]'"
  :group 'lin-faces)

(defface lin-quoted-face
  '((t
     :inherit font-lock-type-face
     ;; :inherit font-lock-string-face
     :weight normal))
  "Face to highlight quoted forms in."
  :group 'lin-faces)

(defface lin-syntax-face
  '((t :inherit font-lock-type-face
       :weight normal))
  "Face to highlight syntax characters in,
i.e. :!&.~ chars when editing Arc code,
and :. chars when editing Lumen code."
  :group 'lin-faces)

(defface lin-identifier-face
  '((t :inherit font-lock-keyword-face
       :weight normal))
  "Face to highlight identifiers in."
  :group 'lin-faces)

(defface lin-global-variable-face
  '((t :inherit font-lock-variable-name-face
       :weight normal))
  "Face to highlight Arc global variables in,
i.e. variables ending with `*' such as `foo*'"
  :group 'lin-faces)

(defface lin-optional-keyword-face
  '((t :inherit lin-global-variable-face
       :weight normal))
  "Face to highlight the Arc optional keyword symbol in,
i.e. the `o' symbol in the following example:

  (def foo (a (o b 42))
    (+ a b))"
  :group 'lin-faces)

(defface lin-thread-local-keyword-face
  '((t :inherit font-lock-keyword-face
       :weight bold))
  "Face to highlight the Arc thread local keyword symbol in,
i.e. the `t' symbol in the following example:

  (def umatch (user (t me))
    (is user me))"
  :group 'lin-faces)

(defface lin-special-operator-face
  '((((background light)) (:foreground "#cb4b16"))
    (((background dark)) (:foreground "#cb4b16")))
  "Face to highlight special operator characters in,
i.e. ,@` chars"
  :group 'lin-faces)

(defface lin-anaphoric-keyword-face
  '((t :inherit lin-identifier-face
       :weight bold))
  "Face to highlight anaphoric keywords `it' and `self' in."
  :group 'lin-faces)

(defface lin-constant-value-face
  '((t :inherit font-lock-string-face
       :weight normal))
  "Face to highlight constant values in.

When editing Lumen code, constant values are: true false nil null
When editing non-Lumen code, constant values are: t nil"
  :group 'lin-faces)

(defface lin-numeric-value-face
  '((t :inherit lin-constant-value-face
       :weight normal))
  "Face to highlight numbers in."
  :group 'lin-faces)

(defvar lin-let-forms '(let with withs atlet atwith atwiths)
  "Forms that take a list of alternating variable/value declarations
as the first argument.")

(defvar-local lin-file-patterns nil
  "Lin font lock patterns for the current file. Should not be changed.")
(put 'lin-file-patterns 'permanent-local t)

(defvar lin-menu
  (let ((map (make-sparse-keymap "Lin")))
    (define-key-after map [lin-find-patterns]
      '(menu-item "Reload" lin-configure
                  :enable lin-mode))
    map)
  "Menu for lin mode.")

(defvar lin-map
  (let ((map (make-sparse-keymap "Lin")))
    ;; (define-key map ...)
    map)
  "Key map for lin.")

(define-minor-mode lin-mode
  "Toggle highlighting and indentation of Lisp forms (Lin mode). With
a prefix argument ARG, enable Lin mode if ARG is positive, and disable
it otherwise. If called from Lisp, enable the mode if ARG is omitted
or nil.

To enable Lin mode in all Lisp buffers, use `global-lin-mode' or add
(global-lin-mode 1) to your init file.

In buffers where Font Lock mode is enabled, various Lisp forms are
highlighted using font lock."
  :group 'lin
  :lighter (:eval (if lin-mode " Lin" ""))
  :global nil
  :keymap lin-map
  (if lin-mode
      ;; Turned on.
      (progn
	(define-key-after menu-bar-tools-menu [lin] (cons "Lin" lin-menu))
	(lin-configure)
        (add-hook 'font-lock-mode-hook 'lin-font-lock-hook nil t)
        (add-hook 'after-save-hook 'lin-after-save-hook nil t)
	(add-hook 'change-major-mode-hook
                  (lambda ()
                    (lin-mode -1)
                    (if global-lin-mode (turn-on-lin-if-enabled)))
                  nil t))
    ;; Turned off.
    (when lin-file-patterns
      (font-lock-remove-keywords nil lin-file-patterns)
      (setq lin-file-patterns nil)
      (remove-overlays nil nil 'lin-overlay t)
      (when font-lock-fontified (font-lock-fontify-buffer)))
    (remove-hook 'font-lock-mode-hook 'lin-font-lock-hook t)
    (remove-hook 'after-save-hook 'lin-after-save-hook t)))

(define-globalized-minor-mode global-lin-mode
  lin-mode turn-on-lin-if-enabled
  :group 'lin)

(defun turn-on-lin-if-enabled ()
  (when (memq (lin-language) '(l el arc scm))
    (lin-mode 1)))

(defun lin-language ()
  (let* ((path (buffer-file-name))
         (ext (if path (file-name-extension path))))
    (cond (ext (intern ext))
          ((derived-mode-p 'lumen-mode) 'l)
          ((derived-mode-p 'arc-mode) 'arc)
          ((derived-mode-p 'scheme-mode) 'scm)
          ((derived-mode-p 'geiser-mode) 'scm)
          ((derived-mode-p 'emacs-lisp-mode) 'el)
          ((derived-mode-p 'numen-mode)
           (when (and (boundp 'numen-lumen-p) numen-lumen-p)
             'l)))))

(defun lin-set-file-patterns (patterns)
  "Replace file patterns list with PATTERNS and refontify."
  (when (or lin-file-patterns patterns)
    (font-lock-remove-keywords nil lin-file-patterns)
    (setq lin-file-patterns patterns)
    (font-lock-add-keywords nil lin-file-patterns t)
    (font-lock-fontify-buffer)))

(defun lin-remove-default-patterns ()
  (let ((kws (list)))
    (dolist (kw (cadr font-lock-keywords))
      (when (listp kw)
        (let ((x (car kw)))
          (when (and (stringp x)
                     (or (string-match-p "|wind-protect" x)
                         (string-match-p "|provide" x)
                         (string-match-p "track-mouse" x)))
            (push kw kws)))))
    (font-lock-remove-keywords nil kws))
  (font-lock-fontify-buffer))

(defun lin-default-indentation-customizations ()
  (cl-case (lin-language)
    ('l (put 'if 'lisp-indent-function 2))
    ('arc
     (put 'fn 'lisp-indent-function 1)
     (cl-dolist (x '(if aif list obj do))
       (put x 'lisp-indent-function 0))
     (cl-dolist (x '(def mac newsop annotate))
       (put x 'lisp-indent-function 'defun)))))

(defvar lin-customize-indentation #'lin-default-indentation-customizations)

(defun lin-trim-whitespace (str)
  (let ((start (cl-position-if-not (lambda (x) (memq x '(?\t ?\n ?\s ?\r))) str))
        (end (cl-position-if-not (lambda (x) (memq x '(?\t ?\n ?\s ?\r))) str :from-end t)))
    (if start (substring str start (1+ end)) "")))

(defun lin-locate-lumen ()
  (let* ((path (shell-command-to-string "which lumen"))
         (path1 (if (stringp path) (lin-trim-whitespace path)))
         (file (if (and path1 (> (length path1) 0))
                   (file-truename path1))))
    (if file (expand-file-name ".." (file-name-directory file)))))

(defun lin-buffer-directory ()
  (let ((path (buffer-file-name)))
    (if path (file-name-directory path))))

(defvar lin-sources
  (list #'lin-locate-lumen
        #'lin-buffer-directory)
  "A list of sources to search for code definitions.
Each entry should be either:
- a path to a code file,
- a path to a directory containing code files,
- or a function returning a list of code files / directories.")

(defun lin--process-sources ()
  (let ((l ()))
    (cl-dolist (x lin-sources)
      (cond ((functionp x)
             (let* ((l1 (funcall x)))
               (setq l (nconc l (if (listp l1) l1 (list l1))))))
            ((stringp x) (setq l (nconc l (list x))))
            ((listp x) (setq l (nconc l x)))
            ((null x) nil)
            (t (error "Unknown lin source type %S" x))))
    (let ((files ()))
      (cl-dolist (path l)
        (cond ((file-directory-p path)
               (cl-dolist (file (directory-files path t "^[^.#][^#~]+$"))
                 (when (and (file-exists-p file) (not (file-directory-p file)))
                   (setq files (nconc files (list file))))))
              ((file-exists-p path)
               (setq files (nconc files (list path))))))
      files)))

(defun lin-get-source-files ()
  (let ((lang (lin-language))
        (l ()))
    (cl-dolist (file (lin--process-sources))
      (let ((ext (file-name-extension file)))
        (when (string= ext (symbol-name lang))
          (push file l))))
    (nreverse l)))

(defun lin-configure-indentation ()
  "Configure Lisp indentation for the current buffer."
  (interactive)
  (unless (derived-mode-p 'emacs-lisp-mode)
    ;; (setq lisp-indent-function 'lisp-indent-function)
    (setq lisp-indent-function 'lin-indent-function)
    (setf comment-indent-function 'calculate-lisp-indent))
  (cl-dolist (file (lin-get-source-files))
    (with-temp-buffer
      (insert-file-contents-literally file)
      (goto-char (point-min))
      (while (re-search-forward "^\\(?:[(][^ \t]+\\|[ \t]+[(]\\(?:def[^ \t]*\\|mac\\)\\)[ \t]+\\([^ \t]+\\).*[ \t]body\\([)]\\|$\\)" nil t)
        (let* ((name (match-string 1))
               (sym (and name (intern name))))
          (when sym
            (put sym 'lisp-indent-function 'defun)
            (put sym 'common-lisp-indent-function 'defun))))))
  (when (functionp lin-customize-indentation)
    (funcall lin-customize-indentation)))

(defun lin--let-form-p (op)
  (or (member op lin-let-forms)
      (string-match-p "^let\\([-*]\\|$\\)" (symbol-name op))))

(defun lin--current-offset ()
  (save-excursion
    (let ((x (point)))
      (beginning-of-line)
      (lin--forward-whitespace)
      (+ (current-indentation)
         (- x (point))))))

(defun lin--start-of-list (&optional n)
  (backward-up-list (or n 1))
  (down-list 1)
  (forward-sexp)
  (backward-sexp))

(defun lin--current-context (&optional n)
  (save-excursion
    (condition-case nil
      (progn
        (lin--start-of-list n)
        (list (symbol-at-point) (point) (lin--current-offset)))
      (scan-error nil))))

(defun lin--forward-char ()
  (let ((p (point)))
    (ignore-errors (forward-char 1))
    (> (point) p)))

(defun lin--forward-whitespace (&optional ws)
  (while (and (looking-at-p (or ws "[ \t\r\n]"))
              (lin--forward-char))
    t)
  (when (looking-at-p "[;]")
    (ignore-errors
      (end-of-line)
      (forward-char 1))
    (lin--forward-whitespace)))

(defun lin--indent (indent-point state)
  (let* ((p (point))
         (l1 (lin--current-context 1))
         (l2 (lin--current-context 2))
         (op1 (car-safe l1))
         (op2 (car-safe l2)))
    (cond ((lin--let-form-p op2)
           (save-excursion
             (goto-char (elt l2 1))
             (if (condition-case nil
                     (progn
                       (forward-sexp 1)
                       (lin--forward-whitespace)
                       (when (looking-at-p "(")
                         (let ((pos (point)))
                           (forward-sexp 1)
                           (and (>= p pos) (<= p (point))))))
                   (scan-error t))
                 (elt l1 2)))))))

(defun lin-indent-function (indent-point state)
  (let ((n (lin--indent indent-point state)))
    (if (integerp n) n (lisp-indent-function indent-point state))))

(defun lin-configure-syntax-table ()
  "Configure Lisp syntax table for the current buffer."
  (let ((lang (lin-language))
        (table (copy-syntax-table (syntax-table))))
    (modify-syntax-entry ?\{ "(}" table)
    (modify-syntax-entry ?\} "){" table)
    (modify-syntax-entry ?\[ "(]" table)
    (modify-syntax-entry ?\] ")[" table)
    (when (eq lang 'l)
      (modify-syntax-entry ?\. "'" table)
      (modify-syntax-entry ?\: "'" table))
    (when (eq lang 'arc)
      (dolist (c '(?^ ?\: ?\~ ?\& ?\. ?\!)) 
        (modify-syntax-entry c "'" table)))
    (unless (eq lang 'el)
      ;; Make hash a usual word character
      (modify-syntax-entry ?# "_ p" table))
    (when (derived-mode-p 'lisp-mode)
      ;; Make | equivalent to "
      (modify-syntax-entry ?\| "\"" table))
    (set-syntax-table table)))

(defun lin-configure-highlighting ()
  "Configure Lisp highlighting for the current buffer."
  (interactive)
  (let ((lang (lin-language)))
    (lin-set-file-patterns
     (delq nil
           (list
             ;; quoted forms
             `("\\(#?'\\|\\_<[?]\\\\.\\|\\_<[?].\\|\\_<#\\\\.\\)[^] \t\r\n\"'(),;[`|]*" (0 'lin-quoted-face))

             ;; numbers
             `("[-+]?\\_<[0-9]+\\(?:\\.[0-9]*\\)?\\_>" (0 'lin-numeric-value-face))

             ;; list operators
             `(,(regexp-opt '(" . " "," ",@" "`")) (0 'lin-special-operator-face))

             ;; Arc foo!bar highlighting
             (when (eq lang 'arc) `("![^] \t\r\n\"'(),;[`|:!&.~]*" (0 'lin-quoted-face)))

             ;; syntax characters
             (when (eq lang 'l) `("[:.]" (0 'lin-syntax-face)))
             (when (eq lang 'arc) `("[:!&.~]+" (0 'lin-syntax-face)))

             ;; Arc anaphoric forms
             (when (eq lang 'arc) `(,(regexp-opt '("it" "self" "_") 'symbols) (0 'lin-anaphoric-keyword-face)))

             ;; Arc global variables
             (when (eq lang 'arc) `("[^] \t\r\n\"'(),;[`|:!&.~]+[*]" (0 'lin-global-variable-face)))

             ;; Arc optional variable keyword
             (when (eq lang 'arc) `(,(concat "[(]\\(" (regexp-opt '("o") 'symbols) "\\)") (1 'lin-optional-keyword-face)))

             ;; Arc thread-local variable keyword
             (when (eq lang 'arc) `(,(concat "[(]\\(" (regexp-opt '("t") 'symbols) "\\)") (1 'lin-thread-local-keyword-face)))

             ;; Arc brackets
             (when (eq lang 'arc) `(,(regexp-opt '("[" "]")) (0 'lin-bracket-face)))

             ;; parens
             `(,(regexp-opt '("(" ")")) (0 'lin-paren-face))

             ;; constant values
             (cl-case lang
               ('scm `(,(regexp-opt '("#t" "#f" "nil") 'symbols) (0 'lin-constant-value-face)))
               ('l `(,(regexp-opt '("true" "false" "nil" "null") 'symbols) (0 'lin-constant-value-face)))
               (t `(,(regexp-opt '("t" "nil") 'symbols) (0 'lin-constant-value-face)))))))

    (unless (eq lang 'el)
      ;; remove Emacs Lisp highlighting
      (lin-remove-default-patterns))))

(defun lin-configure ()
  (interactive)
  (unless (derived-mode-p 'numen-mode)
    (when (memq (lin-language) '(l arc))
      (lin-configure-syntax-table))
    (lin-configure-highlighting))
  (lin-configure-indentation)
  (when (and (derived-mode-p 'numen-mode) (boundp 'numen-lumen-p) numen-lumen-p)
    (lisp-mode-variables nil t)))

(defun lin-font-lock-hook ()
  "Add lin highlighting to font-lock."
  (when font-lock-fontified
    (font-lock-add-keywords nil lin-file-patterns t)))

(defun lin-after-save-hook ()
  (when lin-mode
    (lin-configure)))

(defadvice run-numen (around lin-mode-in-lumen-repl activate)
  "Activate `lin-mode' indentation for Lumen REPLs."
  (prog1 ad-do-it
    (let ((lumenp (ad-get-arg 2)))
      (when lumenp
        (let ((buf (numen-find-repl-buffer)))
          (when buf
            (with-current-buffer buf
              (lin-mode 1))))))))

(provide 'lin)
