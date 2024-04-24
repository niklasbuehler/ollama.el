;;; ollama.el --- ollama client for Emacs

;; Copyright (C) 2024 Niklas Bühler

;; Author: Niklas Bühler <hi@niklasbuehler.com>
;; URL: http://github.com/niklasbuehler/ollama.el
;; Keywords: ollama llm emacs
;; Version: 0.0.1
;; Created: 24th Apr 2024
;; Based on code by ZHOU Feng (http://github.com/zweifisch/ollama)

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; ollama client for Emacs
;;

;;; Code:
;;
;; Boilerplate code for interacting with ollama API:
;;

(require 'json)
(require 'cl-lib)
(require 'url)

(defgroup ollama nil
  "Ollama client for Emacs."
  :group 'ollama)

(defvar ollama:general-model "gemma:2b-instruct" ;; "tinyllama:latest"
  "Model for general processing.")

(defvar ollama:code-model "starcoder:1b"
  "Model for code-related processing.")

(defcustom ollama:endpoint "http://localhost:11434/api/generate"
  "Ollama http service endpoint."
  :group 'ollama
  :type 'string)

(defun ollama-fetch (url prompt model)
  (let* ((url-request-method "POST")
         (url-request-extra-headers
          '(("Content-Type" . "application/json")))
         (url-request-data
          (encode-coding-string
           (json-encode `((model . ,model) (prompt . ,prompt) ("penalize_newline" . "true")))
           'utf-8)))
    (with-current-buffer (url-retrieve-synchronously url)
      (goto-char url-http-end-of-headers)
      (decode-coding-string
       (buffer-substring-no-properties
        (point)
        (point-max))
       'utf-8))))

(defun ollama-get-response-from-line (line)
  (cdr
   (assoc 'response
          (json-read-from-string line))))

(defun ollama-prompt (url prompt model)
  (mapconcat 'ollama-get-response-from-line
             (cl-remove-if #'(lambda (str) (string= str "")) 
                        (split-string (ollama-fetch url prompt model) "\n")) ""))

;;
;; Internal Functions
;;

(defun escape-shell-command (string)
  "Escape special characters in STRING for shell commands."
  (replace-regexp-in-string "'" "'\\\\''" string))

(defun ollama-execute (instruction model)
  "Execute the given INSTRUCTION with the specified MODEL and return the output."
  (ollama-prompt ollama:endpoint instruction model))

(defun ollama-execute-and-paste (instruction model)
  "Execute the given INSTRUCTION with the given MODEL and paste the raw output at the current line."
  (let ((output (ollama-execute instruction model)))
    (save-excursion
      (end-of-line)
      ;; (insert "~Prompt:~ " instruction "\n#+BEGIN_AI " model "\n" output "\n#+END_AI"))))
      (insert output))))

(defun ollama-execute-and-format (instruction model)
  "Execute the given INSTRUCTION with the given MODEL and paste the formatted output below the current line."
  (let ((output (ollama-execute instruction model)))
    (save-excursion
      (end-of-line)
      ;;(insert "\n" output))))
      (insert "~Prompt:~ " instruction "#+BEGIN_AI " model "\n" output "\n#+END_AI"))))

(defun ollama-execute-with-selected-text (instruction model)
  "Concatenate the selected text in Emacs with the given INSTRUCTION and pass it to ollama-execute."
  (let ((selected-text (if (use-region-p)
                           (buffer-substring (region-beginning) (region-end))
                         "\n")))
        (let ((instruction-with-text (if (not (string-empty-p selected-text))
                                        ;;(format (concat instruction " \"\"\"%s\"\"\"") selected-text)
                                        (concat instruction " " selected-text)
                                instruction)))
    (ollama-execute instruction-with-text model))))

(defun ollama-execute-with-selected-text-and-paste (instruction model)
  "Concatenate the selected text in Emacs with the given INSTRUCTION and pass it to ollama-execute-and-paste."
  (let ((selected-text (if (use-region-p)
                           (buffer-substring (region-beginning) (region-end))
                         "\n")))
        (let ((instruction-with-text (if (not (string-empty-p selected-text))
                                        ;;(format (concat instruction " \"\"\"%s\"\"\"") selected-text)
                                        (concat instruction " " selected-text)
                                instruction)))
    (ollama-execute-and-paste instruction-with-text model))))

(defun ollama-execute-with-selected-text-and-format (instruction model)
  "Concatenate the selected text in Emacs with the given INSTRUCTION and pass it to ollama-execute-and-format."
  (let ((selected-text (if (use-region-p)
                           (buffer-substring (region-beginning) (region-end))
                         "\n")))
        (let ((instruction-with-text (if (not (string-empty-p selected-text))
                                        ;;(format (concat instruction " \"\"\"%s\"\"\"") selected-text)
                                        (concat instruction " " selected-text)
                                instruction)))
    (ollama-execute-and-format instruction-with-text model))))

(defun ollama-stream-msg (prompt model)
  "Stream the output of a model from ollama and print a message."
  (interactive "sEnter prompt: ")
  (let* ((output-buffer (generate-new-buffer "*Program Output*"))
         (escaped-prompt (escape-shell-command prompt))
         (command (format "ollama run %s '%s'" model escaped-prompt))
         (proc (start-process "program-output" output-buffer shell-file-name "-c" command)))
    (set-process-filter
     proc
     (lambda (proc output)
       (with-current-buffer (current-buffer)
           (setq output (ansi-color-apply output))
           (setq output (replace-regexp-in-string "[⠁⠂⠃⠄⠅⠆⠇⠈⠉⠊⠋⠌⠍⠎⠏⠐⠑⠒⠓⠔⠕⠖⠗⠘⠙⠚⠛⠜⠝⠞⠟⠠⠡⠢⠣⠤⠥⠦⠧⠨⠩⠪⠫⠬⠭⠮⠯⠰⠱⠲⠳⠴⠵⠶⠷⠸⠹⠺⠻⠼⠽⠾⠿]" "" output))
           (setq output (replace-regexp-in-string "\n" "" output))
           (message output))
       ))
    (set-process-sentinel
     proc
     (lambda (proc status)
       (kill-buffer (process-buffer proc))
       (message "done.")))))

(defun ollama-kill-buffer ()
  "Close the new buffer when the Escape key is pressed."
  (interactive)
  (kill-buffer ollama:cur-buffer)
  (delete-window)
  (switch-to-buffer ollama:prev-buffer))

(defun ollama-insert-buffer-content ()
  "Insert content between delimiters in the new buffer into the original buffer at point."
  (interactive)
  (let* ((content (buffer-substring-no-properties (point-min) (point-max)))
         ;;(begin-pos (string-match "#\\+BEGIN_AI" content))
         (begin-pos 0)
         (end-pos ( + (string-match "#\\+END_AI" content) 8)))
    (when (and begin-pos end-pos)
      (setq content (substring content begin-pos end-pos))
      (with-current-buffer ollama:prev-buffer
        (save-excursion
          (goto-char ollama:paste-position)
          (insert content)))))
    (ollama-kill-buffer))

(defun ollama-insert-raw-buffer-content ()
  "Insert content between delimiters in the new buffer into the original buffer at point."
  (interactive)
  (let* ((content (buffer-substring-no-properties (point-min) (point-max)))
         ;; Find the end of the `#+BEGIN_AI` line to start content just after it
         (begin-pos (string-match-p "#\\+BEGIN_AI" content))
         ;; Adjust `begin-pos` to start after the newline following `#+BEGIN_AI`
         (begin-pos (when begin-pos (- (match-end 0) 1)))
         ;; Find the beginning of the `#+END_AI` to end content just before it
         (end-pos (when begin-pos (string-match-p "#\\+END_AI" content begin-pos))))
    (when (and begin-pos end-pos)
      (setq content (substring content begin-pos end-pos))
      ;; Trim leading and trailing whitespace
      (setq content (string-trim content))
      (with-current-buffer ollama:prev-buffer
        (save-excursion
          (goto-char ollama:paste-position)
          (insert content))))
    (ollama-kill-buffer)))

(defun ollama-stream-buf (prompt model)
  "Stream the output of a model from ollama and print it in a new buffer."
  (interactive "sEnter prompt: ")
  (setq ollama:prev-buffer (current-buffer))
  (setq ollama:paste-position (point))
  (setq ollama:cur-buffer (format "*%s*" model))
  (setq non-space-encountered nil)
  (with-current-buffer (get-buffer-create ollama:cur-buffer)
    (setq buffer-read-only nil)
    (erase-buffer)
    (insert (format "~>>>~ %s\n#+BEGIN_AI %s\n" prompt model))
    (org-mode)
    ;;(switch-to-buffer ollama:cur-buffer))
    (switch-to-buffer-other-window ollama:cur-buffer))
    ;(open-popup-on-side-or-below ollama:cur-buffer))
  (let* ((selected-text (if (use-region-p)
                            (buffer-substring (region-beginning) (region-end))
                          ""))
         (prompt-with-text (concat prompt " " selected-text))
         (escaped-prompt (escape-shell-command prompt))
         (command (format "ollama run %s '%s'" model escaped-prompt))
         (proc (start-process "program-output" ollama:cur-buffer shell-file-name "-c" command)))
    (setq ollama:proc proc)
    (set-process-filter
     proc
     (lambda (proc output)
       (with-current-buffer ollama:cur-buffer
         (setq output (ansi-color-apply output))
         (setq output (replace-regexp-in-string "[⠁⠂⠃⠄⠅⠆⠇⠈⠉⠊⠋⠌⠍⠎⠏⠐⠑⠒⠓⠔⠕⠖⠗⠘⠙⠚⠛⠜⠝⠞⠟⠠⠡⠢⠣⠤⠥⠦⠧⠨⠩⠪⠫⠬⠭⠮⠯⠰⠱⠲⠳⠴⠵⠶⠷⠸⠹⠺⠻⠼⠽⠾⠿]" "" output))
         ;;(setq output (replace-regexp-in-string "^ $" "" output))
         ;;(setq output (replace-regexp-in-string "\n" "" output))
         ;; Check if output contains only whitespace
         (when (string-match-p "^\\s-*$" output)
           ;; If non-space characters have been encountered before, keep the output
           ;; Otherwise, discard it
           (unless non-space-encountered
             (setq output "")))
         ;; Check if output contains non-space characters
         (when (string-match-p "[^[:space:]]" output)
           (setq non-space-encountered t))
         ;; Insert non-empty output
         (unless (string-empty-p output)
           (insert output)))))
    (set-process-sentinel
     proc
     (lambda (proc status)
       ;;(insert "\n\n>> ")
       ;;(evil-insert-state)
       ;;(forward-char)
       ;; TODO Option to continue chat and feed context?
       (with-current-buffer ollama:cur-buffer
         ;; Delete last empty line
         (forward-line -1)
         (kill-whole-line)
         (insert "#+END_AI")
         (insert "\n\nPress 'C-c C-c' or 'p' to insert the raw content in the main buffer.")
         (insert "\nPress 'C-c C-f' or 'P' to insert the formatted content in the main buffer.")
         ;; TODO (insert "\nPress 'C-c C-d' or 'c' to insert any code block content in the main buffer.")
         (insert "\n\nPress 'C-c C-k' or 'Esc' to kill this buffer.")
         (evil-local-set-key 'normal (kbd "C-c C-c") 'ollama-insert-raw-buffer-content)
         (evil-local-set-key 'normal (kbd "p") 'ollama-insert-raw-buffer-content)
         (evil-local-set-key 'normal (kbd "C-c C-f") 'ollama-insert-buffer-content)
         (evil-local-set-key 'normal (kbd "P") 'ollama-insert-buffer-content)
         (evil-local-set-key 'normal (kbd "C-c C-k") 'ollama-kill-buffer)
         (evil-local-set-key 'normal (kbd "<escape>") 'ollama-kill-buffer)
         (setq buffer-read-only t))
       (message "Done.")))
      ;; Ensure the process is killed when the buffer is closed
      ;;(add-hook 'kill-buffer-hook (lambda () (when (process-live-p ollama:proc) (delete-process ollama:proc))) nil t)
     ))

(defun ollama-stream-eol (prompt model)
  "Stream the output of a model from ollama and insert it at the end of the current line."
  (interactive "sEnter prompt: ")
  (message "streaming response...")
  (setq non-space-encountered nil)
  (let* ((output-buffer (generate-new-buffer "*Program Output*"))
         (position (point))
         (escaped-prompt (escape-shell-command prompt))
         (command (format "ollama run %s '%s'" model escaped-prompt))
         (proc (start-process "program-output" output-buffer shell-file-name "-c" command)))
    (set-process-filter
     proc
     (lambda (proc output)
       (with-current-buffer (current-buffer)
           (goto-char (point))
           (setq output (ansi-color-apply output))
           ;; Remove progress indicators (e.g., ⠋) from the output
           (setq output (replace-regexp-in-string "[⠁⠂⠃⠄⠅⠆⠇⠈⠉⠊⠋⠌⠍⠎⠏⠐⠑⠒⠓⠔⠕⠖⠗⠘⠙⠚⠛⠜⠝⠞⠟⠠⠡⠢⠣⠤⠥⠦⠧⠨⠩⠪⠫⠬⠭⠮⠯⠰⠱⠲⠳⠴⠵⠶⠷⠸⠹⠺⠻⠼⠽⠾⠿]" "" output))
           ;; Remove leading whitespace only at the beginning of the output
           ;; (setq output (replace-regexp-in-string "\\`[[:space:]+]+" "" output))
         ;; Check if output contains only whitespace
         (when (string-match-p "^\\s-*$" output)
           ;; If non-space characters have been encountered before, keep the output
           ;; Otherwise, discard it
           (unless non-space-encountered
             (setq output "")))
         ;; Check if output contains non-space characters
         (when (string-match-p "[^[:space:]]" output)
           (setq non-space-encountered t))
         ;; Insert non-empty output
         (unless (string-empty-p output)
           (insert output)))))
    (set-process-sentinel
     proc
     (lambda (proc status)
       (kill-buffer (process-buffer proc))
       (message "done.")))))

;;
;; Callable Functions
;;

(defun ollama/instruct-show (&optional model)
  "Prompt the user for an instruction, execute with the selected text and show the raw output in the message buffer."
  (interactive)
  (let* ((model (or model ollama:general-model))
         (instruction (read-string "Enter instruction: ")))
    (message (ollama-execute-with-selected-text instruction model))))

(defun ollama/instruct-show-stream (&optional model)
  "Prompt the user for an instruction, execute with the selected text and stream the output to a new buffer."
  (interactive)
  (let* ((model (or model ollama:general-model))
         (instruction (read-string "Enter instruction: ")))
    (ollama-stream-buf instruction model)))

(defun ollama/instruct-print (&optional model)
  "Prompt the user for an instruction, execute with the selected text and print the raw output."
  (interactive)
  (let* ((model (or model ollama:general-model))
         (instruction (read-string "Enter instruction: ")))
    (ollama-execute-with-selected-text-and-paste instruction model)))

(defun ollama/instruct-format (&optional model)
  "Prompt the user for an instruction, execute with the selected text and print the formatted output."
  (interactive)
  (let* ((model (or model ollama:general-model))
         (instruction (read-string "Enter instruction: ")))
    (ollama-execute-with-selected-text-and-format instruction model)))

(defun ollama/instruct-stream (&optional model)
  "Prompt the user for an instruction, execute with the selected text, and stream the raw output."
  (interactive)
  (let* ((model (or model ollama:general-model))
         (instruction (read-string "Enter instruction: ")))
    (ollama-stream-eol instruction model)))

(defun ollama/replace-current-line (&optional model)
  "Use the current line as instruction and replace it with the output."
  (interactive)
  (let* ((model (or model ollama:general-model))
         (current-line (buffer-substring (line-beginning-position) (line-end-position)))
         (output (ollama-execute current-line model)))
    (save-excursion
      (delete-region (line-beginning-position) (line-end-position))
      (insert output))))

(defun ollama/replace-current-line-stream (&optional model)
  "Use the current line as instruction and replace it with the output."
  (interactive)
  (let* ((model (or model ollama:general-model))
         (current-line (buffer-substring (line-beginning-position) (line-end-position))))
    (save-excursion
      (delete-region (line-beginning-position) (line-end-position))
      (ollama-stream-eol current-line model))))

(defun ollama/replace-current-selection (&optional model)
  "Prompt for an optional instruction, append the current selection, and replace the selection with the output."
  (interactive)
  (let* ((model (or model ollama:general-model))
         (instruction (read-string "Enter instruction: "))
         (selected-text (if (use-region-p)
                            (buffer-substring (region-beginning) (region-end))
                          ""))
         (instruction-with-text (concat instruction " " selected-text))
         (output (ollama-execute instruction-with-text model)))
    (when (use-region-p)
      (delete-region (region-beginning) (region-end)))
    (insert output)))

(defun ollama/replace-current-selection-stream (&optional model)
  "Prompt for an optional instruction, append the current selection, and replace the selection with the output."
  (interactive)
  (let* ((model (or model ollama:general-model))
         (instruction (read-string "Enter instruction: "))
         (selected-text (if (use-region-p)
                            (buffer-substring (region-beginning) (region-end))
                          ""))
         (instruction-with-text (concat instruction " " selected-text)))
    (when (use-region-p)
      (delete-region (region-beginning) (region-end)))
    (ollama-stream-eol instruction-with-text model)))

(defun ollama/select-model ()
  "Select which model variable to change and choose from the list provided by 'ollama list'."
  (interactive)
  (let* ((model-variable (intern (completing-read "Select model variable: " '(ollama:general-model ollama:code-model))))
         (models (split-string (shell-command-to-string "ollama list") "\n" t))
         (model-names (mapcar (lambda (model) (car (split-string model "\t" t))) models))
         (selected-model (completing-read "Select model: " model-names)))
    (set model-variable selected-model)))

(provide 'ollama)
;;; ollama.el ends here
