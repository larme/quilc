;;;; tests/suite.lisp
;;;;
;;;; Author: Robert Smith

(in-package #:cl-quil-tests)

(defun run-cl-quil-tests (&key (verbose nil) (headless nil) (parallelize nil))
  "Run all CL-QUIL tests. If VERBOSE is T, print out lots of test info. If HEADLESS is T, disable interactive debugging and quit on completion."
  ;; Bug in Fiasco commit fe89c0e924c22c667cc11c6fc6e79419fc7c1a8b
  (setf fiasco::*test-run-standard-output* (make-broadcast-stream
                                            *standard-output*))
  (let ((quil::*compress-carefully* t))
    (cond
      (t
       (setf lparallel:*kernel* (lparallel:make-kernel 2))
       (setf lparallel:*kernel* (lparallel:make-kernel 4))
       (let ((fiasco::*debug-on-unexpected-error* nil)
             (fiasco::*debug-on-assertion-failure* nil)
             (fiasco::*pretty-log-stream*
               (make-instance 'fiasco::column-counting-output-stream
                              :understream *standard-output*))
             (fiasco::*run-test-function* #'pretty-run-test)
             (fiasco::*context* nil))
         (let ((tests (fiasco::children-of
                       (fiasco::find-suite-for-package
                        (fiasco::find-package ':cl-quil-tests)))))
           (lparallel:pmapc (lambda (f)
                              (let ((fiasco::*pretty-log-stream* nil)
                                    (fiasco::*print-test-run-progress* nil)
                                    (fiasco::*pretty-log-verbose-p* nil)
                                    (fiasco::*test-run-standard-output* (make-broadcast-stream))
                                    (*debug-io* (make-broadcast-stream))
                                    )
                                (funcall f)))
                            (loop :for test :being :the :hash-values :of tests
                                  :collect (fiasco::name-of test))))))
      ((null headless)
       (run-package-tests :package ':cl-quil-tests
                          :verbose verbose
                          :describe-failures t
                          :interactive t))
      (t
       (let ((successp (run-package-tests :package ':cl-quil-tests
                                          :verbose t
                                          :describe-failures t
                                          :interactive nil)))
         (uiop:quit (if successp 0 1)))))))

(defun pretty-run-test (test function)
  (labels
      ()
    ;; ((depth-of (context)
    ;;      (let ((depth 0))
    ;;        (loop while (setf context (fiasco::parent-context-of context))
    ;;              do (incf depth))
    ;;        depth))
    ;;    (pp (format-control &rest format-args)
    ;;      ;; (format fiasco::*pretty-log-stream* "~&~v@{~C~:*~}"
    ;;      ;;         (* (depth-of fiasco::*context*) 2) #\Space)
    ;;      ;; (apply #'format fiasco::*pretty-log-stream* format-control format-args
    ;;      1
    ;;      ))
    ;; (pp "~A" (fiasco::name-of test))
    (let* ((*error-output* fiasco::*pretty-log-stream*)
           (*standard-output* fiasco::*pretty-log-stream*)
           (fiasco::*pretty-log-stream* nil)
           (fiasco::*test-run-standard-output* (make-broadcast-stream))
           (retval-v-list (multiple-value-list
                           (fiasco::run-test-body-in-handlers test function)))
           ;; (failures fiasco::(failures-of *context*))
           ;; (skipped fiasco::(skipped-p *context*))
           )
      ;; (format fiasco::*pretty-log-stream* "~v@{~C~:*~}"
      ;;         (max 1 (- *test-progress-print-right-margin*
      ;;                   fiasco::(output-column *pretty-log-stream*)
      ;;                   (length "[FAIL]")))
      ;;         #\.)
      ;; (format fiasco::*pretty-log-stream* "[~A]~%"
      ;;         (cond
      ;;           (skipped  "SKIP")
      ;;           (failures "FAIL")
      ;;           (t        " OK ")))
      (values-list retval-v-list))))
