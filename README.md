## coBra

###### :snake: for [c]oerced [b]racket :snake:

A simple [vim](https://www.vim.org/) plugin that forces brackets and quotes to be smart.

#### install

add this in `.vimrc`
```
Plug 'doums/coBra'
```

then run in vim
```
:PlugInstall
```

#### settings

Default pairs `"'`{([`.
All settings are optional.

To customize the pairs use `g:coBraPairs`, if open character = close character the pair is considered as quotes (different behavior on some situation compared to real brackets)
```
let g:coBraPairs = [
  \  ['"', '"'],
  \  ["'", "'"],
  \  ['`', '`'],
  \  ['{', '}'],
  \  ['(', ')'],
  \  ['[', ']']
  \]
```

Preformance is king when we type. For that reason you can set `g:coBraMaxPendingCloseTry` to a scpecific value between 0 and any positive value, default 10, max `maxfuncdepth`. When you type an openning bracket, before inserting and auto closing it the script looks for a "pending" close bracket that does not have a matching open one. If it find one the script simply inserts the open bracket without auto closing it to complete the pair. `g:coBraMaxPendingCloseTry` limits the number of try of this logic.
```
let g:coBraMaxPendingCloseTry = 10
```

You can set the range of lines (starting from the cursor position) the srcipt run into to preform its logic. Default is all the lines displayed in the current window.
```
let g:coBraLineMax = 20
```

#### features

* smart auto close
* smart auto delete
* mutli line support

#### license
MIT
