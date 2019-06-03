## coBra

###### :snake: for [co]erced [bra]cket :snake:

A simple [vim](https://www.vim.org/) plugin that forces brackets and quotes to be smart.

#### install

Follow the traditional way of your plugin manager.

For Example with [vim-plug](https://github.com/junegunn/vim-plug) add this in `.vimrc`
```
Plug 'doums/coBra'
```

then run in vim
```
:source $MYVIMRC
:PlugInstall
```

#### settings

coBra run in insert mode only, default pairs are ```"'`{([```

coBra will map for insert mode only `<BS>`, `<CR>` and each opener character from the pairs. He expects that no mapping for these keys already exists. If not the concerned mapping will fail.

All settings are optional.

To customize the pairs use `g:coBraPairs`, if open character is the same as close character the pair is considered as quotes (different behavior on some situation compared to real brackets)
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

Preformance is king when we type. For that reason you can set `g:coBraMaxPendingCloseTry` to a scpecific value between 0 and `maxfuncdepth`, default 10. When you type an openning bracket, before inserting and auto closing it the script looks recursively for a "pending" close bracket that does not have a matching open one. If it find one the script simply inserts the open bracket without auto closing it to complete the pair. `g:coBraMaxPendingCloseTry` limits the number of try of this logic.
```
let g:coBraMaxPendingCloseTry = 10
```

You can set the range of lines on which the script is effective to preform its logic (starting from the cursor position). Default is all the lines displayed in the current window.
```
let g:coBraLineMax = 20
```

#### features

* smart auto close
```
| -> [|]
| ] -> [| ]
```
* smart auto delete
```
[|] -> |
[|  ] -> |
```
* smart auto skip close
```
[|] -> [ ]|
```
* smart auto break
```
[|] -> [
         |
       ]
```
* mutli line support
```
[|     |
   ->
]
[      [
 |] ->   ]|
```

#### license
MIT
