;;; test-plz.el --- Tests for plz          -*- lexical-binding: t; -*-

;; Copyright (C) 2019  Adam Porter

;; Author: Adam Porter <adam@alphapapa.net>
;; Keywords:

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

;;

;;; Code:

;;;; Requirements

(require 'ert)
(require 'json)

(require 'plz)

;;;; Variables


;;;; Customization


;;;; Commands


;;;; Macros

(cl-defmacro plz-test-wait (process &optional (seconds 0.1) (times 100))
  "Wait for SECONDS seconds TIMES times for PROCESS to finish."
  `(cl-loop for i upto ,times ;; 10 seconds
            while (equal 'run (process-status ,process))
            do (sleep-for ,seconds)))

;;;; Functions

(defun plz-test-get-response (response)
  "Return non-nil if RESPONSE seems to be a correct GET response."
  (and (plz-response-p response)
       (numberp (plz-response-version response))
       (eq 200 (plz-response-status response))
       (equal "application/json" (alist-get "Content-Type" (plz-response-headers response) nil nil #'equal))
       (let* ((json (json-read-from-string (plz-response-body response)))
              (headers (alist-get 'headers json))
              (user-agent (alist-get 'User-Agent headers nil nil #'equal)))
         (string-match "curl" user-agent))))

;;;; Tests

;;;;; Async

(ert-deftest plz-get-string nil
  (should (let* ((test-string)
                 (process (plz-get "https://httpbin.org/get"
                            :as 'string
                            :then (lambda (string)
                                    (setf test-string string)))))
            (plz-test-wait process)
            (string-match "curl" test-string))))

(ert-deftest plz-get-buffer nil
  ;; The sentinel kills the buffer, so we get the buffer as a string.
  (should (let* ((test-buffer-string)
                 (process (plz-get "https://httpbin.org/get"
                            :as 'buffer
                            :then (lambda (buffer)
                                    (with-current-buffer buffer
                                      (setf test-buffer-string (buffer-string)))))))
            (plz-test-wait process)
            (string-match "curl" test-buffer-string))))

(ert-deftest plz-get-response nil
  (should (let* ((test-response)
                 (process (plz-get "https://httpbin.org/get"
                            :as 'response
                            :then (lambda (response)
                                    (setf test-response response)))))
            (plz-test-wait process)
            (plz-test-get-response test-response))))

(ert-deftest plz-get-json nil
  (should (let* ((test-json)
                 (process (plz-get "https://httpbin.org/get"
                            :as #'json-read
                            :then (lambda (json)
                                    (setf test-json json)))))
            (plz-test-wait process)
            (let* ((headers (alist-get 'headers test-json))
                   (user-agent (alist-get 'User-Agent headers nil nil #'equal)))
              (string-match "curl" user-agent)))))

;;;;; Sync

(ert-deftest plz-get-sync-string nil
  (should (string-match "curl" (plz-get-sync "https://httpbin.org/get"
                                 :as 'string)))
  (should (string-match "curl" (plz-get-sync "https://httpbin.org/get"))))

(ert-deftest plz-get-sync-response nil
  (should (plz-test-get-response (plz-get-sync "https://httpbin.org/get"
                                   :as 'response))))

(ert-deftest plz-get-sync-json nil
  (should (let* ((test-json (plz-get-sync "https://httpbin.org/get"
                              :as #'json-read))
                 (headers (alist-get 'headers test-json))
                 (user-agent (alist-get 'User-Agent headers nil nil #'equal)))
            (string-match "curl" user-agent))))

(ert-deftest plz-get-sync-buffer nil
  ;; `buffer' is not a valid type for `plz-get-sync'.
  (should-error (plz-get-sync "https://httpbin.org/get"
                  :as 'buffer)))

;;;;; Errors

(ert-deftest plz-get-curl-error nil
  (let ((err (should-error (plz-get-sync "https://httpbinnnnnn.org/get/status/404"
                             :as 'string)
                           :type 'plz-curl-error)))
    (should (and (eq 'plz-curl-error (car err))
                 (plz-error-p (cdr err))
                 (equal '(6 . "Couldn't resolve host. The given remote host was not resolved.") (plz-error-curl-error (cdr err)))))))

(ert-deftest plz-get-404-error nil
  (let ((err (should-error (plz-get-sync "https://httpbin.org/get/status/404"
                             :as 'string)
                           :type 'plz-http-error)))
    (should (and (eq 'plz-http-error (car err))
                 (plz-error-p (cdr err))
                 (plz-response-p (plz-error-response (cdr err)))
                 (eq 404 (plz-response-status (plz-error-response (cdr err))))))))

;;;;; Binary

(ert-deftest plz-test-get-jpeg ()
  (let* ((test-jpeg)
         (process (plz-get "https://httpbin.org/image/jpeg"
                    :decode nil
                    :as 'string
                    :then (lambda (string)
                            (setf test-jpeg string)))))
    (plz-test-wait process)
    (should (equal 'jpeg (image-type-from-data test-jpeg)))))

(ert-deftest plz-test-get-jpeg-sync ()
  (let ((jpeg (plz-get-sync "https://httpbin.org/image/jpeg"
                :decode nil)))
    (should (equal 'jpeg (image-type-from-data jpeg)))))

;;;; Footer

(provide 'test-plz)

;;; test-plz.el ends here