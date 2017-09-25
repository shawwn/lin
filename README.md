lin
=

# Download

Lin lives in a git repository. To download Lin, do

```
git clone https://github.com/emacs-lin/lin ~/.emacs.d/lin
```

# Install

After the download step, add the following lines to `~/.emacs`:

```elisp
(add-to-list 'load-path "~/.emacs.d/lin")
(require 'lin)
(global-lin-mode 1)
```

## Dependencies

None, but [rainbow-delimiters](https://github.com/Fanael/rainbow-delimiters)
is handy.
