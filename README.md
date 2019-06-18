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

coBra runs in insert mode only, default pairs are ```"'`{([```

coBra works by buffer and more precisely by file type. Be sure to have the `filetype` option on (you can check it with `:filetype`, and look for "detection:ON"). This way coBra will use the corresponding set of pairs if available (defined with `g:coBraPairs`). If not he will use the default one.

coBra will map for insert mode only `<BS>`, `<CR>` and the two characters of each pair. He expects that no mapping for these keys already exists. If not the concerned mapping will fail.

All settings are optional.

To customize the pairs use `g:coBraPairs`, if the open character is the same as the close character the pair is considered as quotes (different behavior on some situation compared to real brackets).
You have to enter a set of pairs by file type. Of course you can customize the default set too.
```
let g:coBraPairs = {
  \  'default': [
  \    ['"', '"'],
  \    ["'", "'"],
  \  ],
  \  'rust': [
  \    ['"', '"'],
  \    ['<', '>'],
  \    ['{', '}'],
  \    ['(', ')'],
  \    ['[', ']']
  \  ]
  \ }
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

* auto close
```
| -> [|]
| ] -> [| ]
```
* auto delete
```
[|] -> |
[|  ] -> |
```
* auto skip
```
[|] -> [ ]|
```
* auto break
```
[|] -> [
         |
       ]
```
* mutli lines support
```
[|     |
   ->
]
[      [
 |] ->   ]|
```

#### license
MIT
