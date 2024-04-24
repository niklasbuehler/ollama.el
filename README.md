🦙 ollama.el
===

Local LLMs in Emacs with [Ollama](https://ollama.com/)!

## Demo

A quick demo video, showcasing most features, using a small 2b LLM running locally on my old laptop:

[![Demo: Local LLM in Emacs](http://img.youtube.com/vi/moaFwXEaBTY/0.jpg)](http://www.youtube.com/watch?v=moaFwXEaBTY "Local LLM in Emacs")

## Features

- Various input/output patterns
  + Pass current line/selection as input (with or without additional prompt)
  + Preview buffers for output with various options to paste/discard
  + Replace current line/selection with output
  + Paste output as formatted AI block (including prompt)
  + Paste raw output
- Support for streaming results
- Support for accessing different models for different use cases

## Installation

1. Install [Ollama](https://ollama.com/download) and at least one of the many [available models](https://ollama.com/library).
2. Install this package in Emacs.

For the second step, refer to your Emacs package manager for installation instructions of new packages.

### Doom Emacs

In [Doom Emacs](https://github.com/doomemacs/doomemacs), you can install `ollama.el` by adding this snippet to your `packages.el` and running `doom sync` and `M-x doom reload` afterwards:

```emacs-lisp
(package ollama
  :recipe (:host github :repo "niklasbuehler/ollama.el"))
```

### Local Loading

Alternatively, you can also download the `ollama.el` file and [load it locally](https://www.gnu.org/software/emacs/manual/html_node/eintr/Loading-Files.html).

## Usage

Here's an example keymap for Doom Emacs, showing several ways to use the provided functions:

```emacs-lisp
(map! :leader
      (:prefix-map ("l" . "LLMs from ollama")
       :desc "Prompt" "l" #'ollama/instruct-show-stream
       :desc "Paste output" "p" #'ollama/instruct-stream
       :desc "Paste output (sync)" "P" #'ollama/instruct-print
       :desc "Paste formatted output" "o" #'ollama/instruct-format
       :desc "Replace current line" "r" #'ollama/replace-current-line-stream
       :desc "Replace current selection" "R" #'ollama/replace-current-selection-stream
       :desc "Access Code Model" "c" nil
       :desc "Prompt" "c l" (lambda () (interactive) (ollama/instruct-show ollama:code-model))
       :desc "Paste output" "c p" (lambda () (interactive) (ollama/instruct-stream ollama:code-model))
       :desc "Paste output (sync)" "c P" (lambda () (interactive) (ollama/instruct-print ollama:code-model))
       :desc "Paste formatted output" "c o" (lambda () (interactive) (ollama/instruct-format ollama:code-model))
       :desc "Replace current line" "c r" (lambda () (interactive) (ollama/replace-current-line ollama:code-model))
       :desc "Replace current selection" "c R" (lambda () (interactive) (ollama/replace-current-selection ollama:code-model))
       :desc "Select active model" "s" #'ollama/select-model))
```

## Acknowledgement

The boilerplate code for interacting synchronously with the Ollama API is based on code from [this package](https://github.com/zweifisch/ollama/blob/master/ollama.el).
