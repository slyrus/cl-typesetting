;;; cl-typesetting copyright 2002 Marc Battyani see license.txt for details of the license
;;; You can reach me at marc.battyani@fractalconcept.com or marc@battyani.net

(in-package typeset)

(defclass style ()
  ((name :accessor name :initform nil)))

(defmethod use-style (style)
  )

(defmethod style-p ((style style))
  t)

(defmethod style-p (obj)
  nil)

(defclass text-style (style)
  ((font :accessor font :initform nil)
   (font-size :accessor font-size :initarg :font-size :initform nil)
   (text-x-scale :accessor text-x-scale :initarg :text-x-scale :initform nil)
   (color :accessor color :initarg :color :initform nil)
   (background-color :accessor background-color :initarg :background-color :initform nil)
   (h-align :accessor h-align :initarg :h-align :initform nil)
   (left-margin :accessor left-margin :initarg :left-margin :initform nil)
   (right-margin :accessor right-margin :initarg :right-margin :initform nil)))

(defmethod initialize-instance :after ((obj text-style) &rest args &key font &allow-other-keys)
    (when font (setf (font obj) font)))

(defmethod (setf font) :around (font (style text-style))
  (when (stringp font)(setf font (pdf:get-font font)))
  (call-next-method font style))

(defclass text-content ()
  ((boxes :accessor boxes)
   (boxes-tail :accessor boxes-tail)
   (text-style :accessor text-style)))

(defmethod initialize-instance :after ((obj text-content) &rest args &key &allow-other-keys)
  (clear-content obj)
  (setf (text-style obj)
	(apply 'make-instance 'text-style args)))

(defun add-box-to-content (content box)
  (when content
    (setf (boxes-tail content) (setf (cdr (boxes-tail content)) (list box))))
  box)

(defun clear-content (content)
  (setf (boxes content)(list :start))
  (setf (boxes-tail content)(boxes content)))

(defclass executable-box (soft-box h-mode-mixin)
  ())

(defclass function-box (executable-box)
  ((fn :accessor fn :initarg :fn)))

(defmethod execute-box ((box executable-box))
  nil)

(defmethod execute-box ((box function-box))
  (funcall (fn box)))

(defmethod use-style ((style text-style))
  (macrolet ((%use-style% (name var)
	       `(let ((style (,name style)))
		 (when style (setf ,var style)))))
    (%use-style% font *font*)
    (%use-style% font-size *font-size*)
    (%use-style% text-x-scale *text-x-scale*)
    (%use-style% color *color*)
    (%use-style% background-color *background-color*)
    (%use-style% left-margin *left-margin*)
    (%use-style% right-margin *right-margin*)
    (%use-style% h-align *h-align*))
  (when (or (font style)(font-size style))
    (setf *leading* (* *font-size* *leading-ratio*))))

(defmethod save-style ((style text-style))
  (setf (font style) *font*)
  (setf (font-size style) *font-size*)
  (setf (text-x-scale style) *text-x-scale*)
  (setf (color style) *color*)
  (setf (background-color style) *background-color*)
  (setf (left-margin style) *left-margin*)
  (setf (right-margin style) *right-margin*)
  (setf (h-align style) *h-align*))

(defmethod restore-default-style ((style text-style))
  (setf (font style) *default-font*)
  (setf (font-size style) *default-font-size*)
  (setf (text-x-scale style) *default-text-x-scale*)
  (setf (color style) *default-color*)
  (setf (background-color style) *default-background-color*)
  (setf (left-margin style) *default-left-margin*)
  (setf (right-margin style) *default-right-margin*)
  (setf (h-align style) *default-h-align*))

(defmethod make-restore-style ((style text-style))
  (let ((new-style (make-instance 'text-style)))
    (macrolet ((%use-style% (name var)
		 `(when (,name style)
		   (setf (,name new-style) ,var))))
      (%use-style% font *font*)
      (%use-style% font-size *font-size*)
      (%use-style% text-x-scale *text-x-scale*)
      (%use-style% color *color*)
      (%use-style% left-margin *left-margin*)
      (%use-style% right-margin *right-margin*)
      (%use-style% h-align *h-align*))
    new-style))

(defmethod copy-style ((style text-style))
  (make-instance 'text-style :font (font style) :font-size (font-size style)
		 :text-x-scale (text-x-scale style)
		 :color (color style)
		 :left-margin (left-margin style)
		 :right-margin (right-margin style)
		 :h-align (h-align style)))

(defclass text-line (hbox)
  ())

(defun make-char-box (char)
  (if *use-exact-char-boxes*
      (multiple-value-bind (width ascender descender) (pdf:get-char-size char *font* *font-size*)
	(setq width (* width *text-x-scale*))
	(make-instance 'char-box :boxed-char char :dx width :dy (- ascender descender) :baseline ascender))
    (make-instance 'char-box :boxed-char char :dx (* (pdf:get-char-width char *font* *font-size*)
						     *text-x-scale*)
		   :dy *leading* :baseline *font-size*)))

(defun make-white-char-box (char &optional (trimable-p t))
  (let ((width (* (pdf:get-char-width char *font* *font-size*) *text-x-scale*)))
    (make-instance 'white-char-box :trimable-p trimable-p
		   :dx width :max-expansion (* width 10) :max-compression (* width 0.7)
		   :expansibility (* width 2.0) :compressibility width)))

(defun make-not-trimable-white-char-box (char)
  (let ((width (* (pdf:get-char-width char *font* *font-size*) *text-x-scale*)))
    (make-instance 'h-spacing :dx width :max-expansion width :max-compression width)))

(defun make-kerning-space (dx)
  (make-instance 'hglue :dx dx :locked t))

(defun make-ponctuation-space-box (char)
  (let ((width (* (pdf:get-char-width char *font* *font-size*) *text-x-scale*))
	(space-params (cdr (assoc char *ponctuation-marks-extra-spacing-ratios* :test #'char=))))
    (when space-params
      (destructuring-bind (w max-exp exp max-compr compr) space-params
	  (make-instance 'white-char-box :dx (* width w)
			 :max-expansion (* width max-exp)
			 :expansibility (* width exp)
			 :max-compression (* width max-compr)
			 :compressibility (* width compr))))))

(defun make-hfill-glue ()
  (make-instance 'h-spacing :dx 0 :max-expansion +huge-number+ :expansibility +huge-number+))

(defun make-vfill-glue ()
  (make-instance 'v-spacing :dy 0 :max-expansion +huge-number+ :expansibility +huge-number+))

(defun make-inter-char-glue ()
  (make-instance 'hglue :dx 0 
		 :max-expansion (* *font-size* 0.09 *text-x-scale*)
		 :max-compression (* *font-size* 0.04 *text-x-scale*)
		 :expansibility 0.5 :compressibility 0.25))

(defun make-inter-line-glue (spacing)
  (make-instance 'vglue :dy 0 :max-expansion (* spacing 2) :max-compression (* spacing 0.7)
		 :expansibility 1.0 :compressibility 0.5))

(defun make-h-spacing (dx)
  (make-instance 'h-spacing :dx dx :max-expansion (* dx 3) :max-compression (* dx 0.7)
		 :expansibility 2.0 :compressibility 1.0))

(defun make-v-spacing (dy)
  (make-instance 'v-spacing :dy dy :max-expansion (* dy 3) :max-compression (* dy 0.7)
		 :expansibility 2.0 :compressibility 1.0))

(defun add-box (box)
  (when box
    (add-box-to-content *content* box)))

(defun ponctuation-mark-p (char)
  (find char *ponctuation-marks*))

(defun white-char-p (char)
  (find char *white-chars*))

(defun put-string (string)
  (when (stringp string)
    (let ((hyphen-points (hyphenate-string string)))
      (loop with hyphen-point = (pop hyphen-points)
	  for prev-char = #\I then char
	  for char across string
	  for i from 0
	  for kerning = (* (pdf:get-kerning prev-char char *font* *font-size*) *text-x-scale*)
	  do
	    (when (and hyphen-point (= i hyphen-point))
	      (setf hyphen-point (pop hyphen-points))
	      (add-box (make-instance 'hyphen-box :char-box (make-char-box #\-))))
	    (cond
	     ((white-char-p char)
	      (cond
	       ((white-char-p prev-char) nil)
	       ((ponctuation-mark-p prev-char)(add-box (make-ponctuation-space-box prev-char)))
	       (t (add-box (make-white-char-box #\Space)))))
	     (t (unless (zerop kerning)
		  (add-box (make-kerning-space kerning)))
		(add-box (make-char-box char))
		(add-box (make-inter-char-glue))))))))

;;; put a source code string: no kerning, no hyphenation, significant whitespaces, significant returns
(defun put-source-code-string (string)
  (when (stringp string)
    (loop for char across string
	  for i from 0
	  do
	    (cond
	      ((char= char #\Newline)(add-box :eol))
	      ((white-char-p char)(add-box (make-white-char-box char nil)))
	      (t (add-box (make-char-box char))
		 (add-box (make-inter-char-glue)))))))

(defun new-line ()
  (add-box :eol))

(defun new-page ()
  (add-box :eop))

(defmethod insert-stuff ((obj t))
  obj)

(defmethod insert-stuff ((obj string))
  `(put-string ,obj))

(defmethod insert-stuff ((obj (eql :eol)))
  '(new-line))

(defmethod insert-stuff ((obj (eql :eop)))
  '(new-page))

(defmethod insert-stuff ((obj (eql :vfill)))
  '(add-box (make-vfill-glue)))

(defmethod insert-stuff ((obj (eql :hfill)))
  '(add-box (make-hfill-glue)))

(defmethod insert-stuff ((obj symbol))
  `(put-string (format nil "~a" ,obj)))

(defmacro with-text-content ((content &key dont-save-style) &body body)
  (with-gensyms (the-content)
    `(let* ((,the-content ,content)
	    (*content* ,the-content)
	    (*font* *default-font*)
	    (*font-size* *default-font-size*)
	    (*text-x-scale* *default-text-x-scale*)
	    (*color* *default-color*)
	    (*background-color* *default-background-color*)
	    (*h-align* *default-h-align*)
	    (*v-align* *default-v-align*)
	    (*left-margin* *default-left-margin*)
	    (*right-margin* *default-right-margin*))
      (use-style (text-style ,the-content))
      (prog1 (progn ,@body)
	(unless ,dont-save-style (save-style (text-style ,the-content)))))))

(defmacro compile-text ((&rest args) &body body)
  `(with-text-content ((make-instance 'text-content ,@args) :dont-save-style t)
    (add-box (copy-style (text-style *content*)))
    ,@(mapcar 'insert-stuff body)
    *content*))

(defmacro with-style ((&rest style) &body body)
  (with-gensyms (new-style restore-style)
    `(let* ((,new-style (make-instance 'text-style ,@style))
	    (,restore-style (make-restore-style ,new-style)))
      (add-box ,new-style)
      (use-style ,new-style)
      ,@(mapcar 'insert-stuff body)
      (add-box ,restore-style)
      (use-style ,restore-style))))

(defmacro set-style ((&rest style) &body body)
  (with-gensyms (new-style)
    `(let ((,new-style (make-instance 'text-style ,@style)))
      (add-box ,new-style)
      (use-style ,new-style)
      ,@(mapcar 'insert-stuff body))))

(defmacro with-offset ((offset) &body body)
  `(let* ((*offset* ,offset))
    ,@(mapcar 'insert-stuff body)))

(defmacro with-superscript ((&key (offset '(* 0.45 *font-size*))
			     (font-size '(* 0.5 *font-size*)))
		       &body body)
  `(let* ((*offset* (+ *offset* ,offset)))
    (with-style (:font-size ,font-size) ,@body)))

(defmacro with-subscript ((&key (offset '(* -0.2 *font-size*))
			   (font-size '(* 0.5 *font-size*)))
		     &body body)
  `(let* ((*offset* (+ *offset* ,offset)))
    (with-style (:font-size ,font-size) ,@body)))

(defmacro paragraph ((&rest style) &body body)
  (with-gensyms (new-style restore-style first-indent)
    (let ((top-margin (getf style :top-margin 0))
	  (bottom-margin (getf style :bottom-margin 0))
	  (first-line-indent (getf style :first-line-indent 0)))
      `(let* ((,new-style (make-instance 'text-style ,@style))
	      (,restore-style (make-restore-style ,new-style))
	      (,first-indent ,first-line-indent))
	(add-box ,new-style)
	(use-style ,new-style)
	(add-box (make-instance 'v-spacing :dy ,top-margin))
	(unless (zerop ,first-indent)
	  (add-box (make-instance 'h-spacing :dx ,first-indent)))
	,@(mapcar 'insert-stuff body)
	(unless (eq (first (boxes-tail *content*)) :eol)
	  (add-box :eol))
	(add-box (make-instance 'v-spacing :dy ,bottom-margin))
	(add-box ,restore-style)
	(use-style ,restore-style)))))

(defun vspace (space)
  (add-box (make-v-spacing space)))

(defun hspace (space)
  (add-box (make-h-spacing space)))

(defmacro vbox ((&key (align :top) adjustable-p) &body body)
  (with-gensyms (vbox)
    `(let (,vbox)
      (let ((*content* (make-instance 'text-content)))
	,@(mapcar 'insert-stuff body)
	(setf ,vbox (make-instance 'vbox :adjustable-p ,adjustable-p
				   :boxes (rest (boxes *content*)))))
      (align-baseline ,vbox ,align)
      (add-box ,vbox))))

(defmacro hbox ((&key (align :left) adjustable-p) &body body)
  (with-gensyms (hbox)
    `(let (,hbox)
      (let ((*content* (make-instance 'text-content)))
	,@(mapcar 'insert-stuff body)
	(setf ,hbox (make-instance 'hbox :adjustable-p ,adjustable-p
				   :boxes (rest (boxes *content*)))))
      (align-baseline ,hbox ,align)
      (add-box ,hbox))))
