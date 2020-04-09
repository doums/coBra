" This Source Code Form is subject to the terms of the Mozilla Public
" License, v. 2.0. If a copy of the MPL was not distributed with this
" file, You can obtain one at https://mozilla.org/MPL/2.0/.

" coBra
"
" for [co]erced [bra]cket
" author Pierre Dommerc
" dommerc.pierre@gmail.com

" script {{{

let s:save_cpo = &cpo
set cpo&vim

if exists("g:coBra")
  finish
endif
let g:coBra = 1

let g:defaultPairs = [
      \  ['"', '"'],
      \  ["'", "'"],
      \  ['`', '`'],
      \  ['{', '}'],
      \  ['(', ')'],
      \  ['[', ']']
      \ ]

if !exists('g:coBraPairs')
  let g:coBraPairs = { 'default': g:defaultPairs }
elseif !has_key(g:coBraPairs, 'default')
  let g:coBraPairs.default = g:defaultPairs
endif

if !exists('g:coBraMaxPendingCloseTry')
  let g:coBraMaxPendingCloseTry = 10
endif

let s:recursiveCount = 0

augroup coBra
  autocmd!
  autocmd BufEnter * call s:Init()
  autocmd FileType * call s:Init(expand("<amatch>"))
augroup END

function s:Init(...)
  if a:0 == 1
    for type in keys(g:coBraPairs)
      if type == a:1
        return s:SetPairsAndMap(type)
      endif
    endfor
  else
    for type in keys(g:coBraPairs)
      if type == &filetype
        return s:SetPairsAndMap(type)
      endif
    endfor
  endif
  call s:SetPairsAndMap('default')
endfunction

function s:SetPairsAndMap(type)
  if exists("b:pairs") && b:pairs is g:coBraPairs[a:type]
    return
  endif
  let b:pairs = g:coBraPairs[a:type]
  for [open, close] in b:pairs
    if !s:AreQuotes(open, close)
      execute 'inoremap <buffer><expr><silent> '.open.
            \' <SID>AutoClose("'.escape(open, '"').'", "'.escape(close, '"').'")'
      execute 'inoremap <buffer><expr><silent> '.close.
            \' <SID>SkipClose("'.escape(open, '"').'", "'.escape(close, '"').'")'
    else
      execute 'inoremap <buffer><expr><silent> '.open.' <SID>ManageQuote("'.escape(open, '"').'")'
    endif
    execute 'vnoremap <buffer><expr> <Leader>'.open.' <SID>VisualBracket("'
          \ .escape(open, '"').'", "'.escape(close, '"').'")'
  endfor
  inoremap <buffer><expr> <BS> <SID>AutoDelete()
  inoremap <buffer><expr> <CR> <SID>AutoBreak()
endfunction

" {{{ visual
function s:IsWrappedBy(selection)
  for [open, close] in b:pairs
    if a:selection.start.char ==# open
          \ && a:selection.end.char ==# close
      if s:AreQuotes(open, close)
        return 1
      else
        return 2
      endif
    endif
  endfor
  return 0
endfunction

function s:GetCurrentSelection()
  if mode() !=# "v"
    return 0
  endif
  let start = getpos("v")
  let end = getcurpos()
  if start[1] > end[1] || (start[1] == end[1] && start[2] > end[2])
    let tmp = start
    let start = end
    let end = tmp
  endif
  let startChar = getline(start[1])[start[2] - 1]
  let endChar = getline(end[1])[end[2] - 1]
  let cursorAtEnd = 1
  let cursor = getcurpos()
  if cursor[1] == start[1] && cursor[2] == start[2]
    let cursorAtEnd = 0
  endif
  return {
        \ "start": { "pos": [start[1], start[2]], "char": startChar },
        \ "end": { "pos": [end[1], end[2]], "char": endChar },
        \ "cursorAtEnd": cursorAtEnd
        \ }
endfunction

function s:WrapBy(selection, open, close)
  let cursor = getcurpos()
  let goToStart = a:selection.start.pos[0]."G".a:selection.start.pos[1]."|"
  let endOffset = 0
  if a:selection.start.pos[0] == a:selection.end.pos[0]
    let endOffset = 1
  endif
  let goToEnd = a:selection.end.pos[0]."G".(a:selection.end.pos[1] + endOffset)."|"
  let a:selection.start.pos[1] += 1
  let a:selection.end.pos[1] -= (1 + endOffset)
  return "\<Esc>".goToStart."i".a:open."\<Esc>".goToEnd."a".a:close."\<Esc>".s:Select(a:selection)
endfunction

function s:ReplaceBy(selection, open, close)
  let cursor = getcurpos()
  let goToStart = a:selection.start.pos[0]."G".a:selection.start.pos[1]."|"
  let goToEnd = a:selection.end.pos[0]."G".a:selection.end.pos[1]."|"
  let a:selection.start.pos[1] += 1
  let a:selection.end.pos[1] -= 1
  return "\<Esc>".goToStart."s".a:open."\<Esc>".goToEnd."s".a:close."\<Esc>".s:Select(a:selection)
endfunction

function s:Select(selection)
  let goToStart = a:selection.start.pos[0]."G".a:selection.start.pos[1]."|"
  let goToEnd = a:selection.end.pos[0]."G".a:selection.end.pos[1]."|"
  if a:selection.cursorAtEnd
    return goToStart."v".goToEnd
  else
    return goToEnd."v".goToStart
  endif
endfunction

function s:VisualBracket(open, close)
  let selection = s:GetCurrentSelection()
  if empty(selection) || (
        \   selection.start.pos[0] == selection.end.pos[0]
        \   && selection.start.pos[1] == selection.end.pos[1]
        \ )
    return ""
  endif
  let isWrapped = s:IsWrappedBy(selection)
  if !isWrapped
    return s:WrapBy(selection, a:open, a:close)
  elseif isWrapped == 2
        \ && selection.start.char ==# a:open && selection.end.char ==# a:close
    return s:WrapBy(selection, a:open, a:close)
  elseif isWrapped == 1
        \ && selection.start.char ==# a:open && selection.end.char ==# a:close
    let selection.start.pos[1] += 1
    let selection.end.pos[1] -= 1
    return "\<Esc>".s:Select(selection)
  elseif isWrapped == 1 && s:AreQuotes(a:open, a:close)
    return s:ReplaceBy(selection, a:open, a:close)
  elseif isWrapped == 1 && !s:AreQuotes(a:open, a:close)
    return s:WrapBy(selection, a:open, a:close)
  elseif isWrapped == 2 && s:AreQuotes(a:open, a:close)
    return s:WrapBy(selection, a:open, a:close)
  elseif isWrapped == 2 && !s:AreQuotes(a:open, a:close)
    return s:ReplaceBy(selection, a:open, a:close)
  endif
  return ""
endfunction
" }}}

" manage quote {{{
function s:ManageQuote(quote)
  if s:IsString(line("."), col("."))
        \ && s:IsString(line("."), col(".") - 1)
        \ && getline(".")[col(".") - 1] == a:quote
        \ && !s:IsEscaped()
    return "\<Right>"
  endif
  return s:AutoClose(a:quote, a:quote)
endfunction
" }}}

" {{{ auto close
function s:AutoClose(open, close)
  if s:IsEscaped()
        \ || s:IsString(line("."), col("."))
        \ || s:IsComment(line("."), col("."))
        \ || s:IsPendingClose(a:open, a:close)
    return a:open
  endif
  if !s:IsBeforeOrInsideWord()
    return a:open.a:close."\<Left>"
  endif
  return a:open
endfunction

function s:SkipClose(open, close)
  if getline(".")[col(".") - 1] == a:close
        \ && searchpair(s:Escape(a:open),
        \ '',
        \ s:Escape(a:close),
        \ 'cnW',
        \ 's:IsString(line("."), col(".")) || s:IsComment(line("."), col("."))',
        \ s:GetLineBoundary('f')) > 0
    return "\<Right>"
  endif
  return a:close
endfunction
" }}}

" auto break {{{
function s:AutoBreak()
  for [open, close] in b:pairs
    if open != close && getline(line("."))[col(".") - 2] == open
      let [line, col] = searchpairpos(s:Escape(open),
            \ '',
            \ s:Escape(close),
            \ 'cnW',
            \ 's:IsString(line("."), col(".")) || s:IsComment(line("."), col("."))',
            \ s:GetLineBoundary('f'))
      if line == line(".") &&
            \ match(getline("."), '^'.s:Escape(open).'\s*'.s:Escape(close), col(".") - 2) > -1
        return "\<CR>\<CR>\<Up>\<C-f>"
      endif
    endif
  endfor
  return "\<CR>"
endfunction
" }}}

" pending close {{{
function s:IsPendingClose(open, close)
  if a:open == a:close
    return
  endif
  let currentLine = line(".")
  let currentCol = col(".")
  let s:recursiveCount = 0
  if s:UnderCursorSearch(a:open, a:close, s:GetLineBoundary('b'))
    return v:true
  endif
  let result = s:RecursiveSearch(a:open, a:close, s:GetLineBoundary('f'), s:GetLineBoundary('b'))
  call cursor(currentLine, currentCol)
  return result
endfunction

function s:UnderCursorSearch(open, close, stopLine)
  if getline(".")[col(".") - 1] == a:close && !s:IsArrowOrGreaterLessSign(a:close, line("."), col(".") - 1)
    let [line, col] = searchpairpos(s:Escape(a:open),
          \ '',
          \ s:Escape(a:close),
          \ 'bWn',
          \ 's:IsString(line("."), col(".")) || s:IsComment(line("."), col("."))',
          \ a:stopLine)
    if line == 0 && col == 0
      return v:true
    endif
  endif
endfunction

function s:RecursiveSearch(open, close, maxForward, maxBackward)
  if s:recursiveCount >= &maxfuncdepth - 10 || s:recursiveCount >= g:coBraMaxPendingCloseTry
    return
  endif
  let s:recursiveCount = s:recursiveCount + 1
  let [line, col] = searchpos(s:Escape(a:close), 'eWz', a:maxForward)
  if line == 0 && col == 0
    return
  endif
  if s:IsString(line, col) ||
        \ s:IsComment(line, col) ||
        \ s:IsArrowOrGreaterLessSign(a:close, line, col - 1)
    return s:RecursiveSearch(a:open, a:close, a:maxForward, a:maxBackward)
  endif
  let [pairLine, pairCol] = searchpairpos(s:Escape(a:open),
        \ '',
        \ s:Escape(a:close),
        \ 'bnW',
        \ 's:IsString(line("."), col(".")) || s:IsComment(line("."), col(".")) || s:IsArrowOrGreaterLessSign(a:open, line("."), col(".") - 1)',
        \ a:maxBackward)
  if pairLine == 0 && pairCol == 0
    return v:true
  endif
  return s:RecursiveSearch(a:open, a:close, a:maxForward, a:maxBackward)
endfunction
" }}}

" auto delete {{{
function s:AutoDelete()
  for [open, close] in b:pairs
    if open == close
      let result = s:DeleteQuotes(open)
      if !empty(result)
        return result
      endif
    else
      let result = s:DeletePair(open, close)
      if !empty(result)
        return result
      endif
    endif
  endfor
  return "\<BS>"
endfunction

function s:DeletePair(open, close)
  if getline(".")[col(".") - 2] == a:open
        \ && getline(".")[col(".") - 3] != '\'
    let [line, col] = searchpairpos(s:Escape(a:open),
          \ '',
          \ s:Escape(a:close),
          \ 'cnW',
          \ '',
          \ s:GetLineBoundary('f'))
    if line == 0 && col == 0
      return
    endif
    let start = {'line': line("."), 'col': col(".")}
    let end = {'line': line, 'col': col}
    if start.line == end.line && end.col == start.col
      return "\<Del>\<BS>"
    endif
    if s:IsPairEmpty(a:open, a:close, start, end)
      if start.line == end.line
        let toEnd = end.col - 2
        let toStart = ''
        if start.col - 2 > 0
          let toStart = (start.col - 2).'l'
        endif
        return "\<BS>\<Esc>0".toEnd.'lx0'.toStart.'i'
      else
        let toEnd = ''
        let toStart = ''
        let insertMotion = ''
        if end.col - 1 > 0
          let toEnd = (end.col - 1).'l'
        endif
        let i = 0
        if start.col == col("$")
          let i = start.col - 3
          if col("$") - 1 > 1
            let insertMotion = "\<Right>"
          endif
        else
          let i = start.col - 2
        endif
        if i > 0
          let toStart = i.'l'
        endif
        return "\<BS>\<Esc>".end.line.'G0'.toEnd.'x'.start.line.'G0'.toStart.'i'.insertMotion
      endif
    endif
  endif
endfunction

function s:IsPairEmpty(open, close, start, end)
  if a:start.line == a:end.line
    let [line, col] = searchpos(s:Escape(a:open).'\s*'.s:Escape(a:close), 'bW', a:start.line)
  else
    let [line, col] = searchpos(s:Escape(a:open).'\(\s*\n\)\{'.(a:end.line - a:start.line).'}\s*'.s:Escape(a:close), 'bW', a:start.line)
  endif
  if line == a:start.line && col == a:start.col - 1
    return v:true
  endif
endfunction

function s:DeleteQuotes(quote)
  if getline(".")[col(".") - 1] == a:quote
        \ && getline(".")[col(".") - 2] == a:quote
        \ && !s:IsComment(line("."), col(".") - 1)
        \ && !s:IsString(line("."), col(".") + 1)
        \ && !s:IsString(line("."), col(".") - 2)
        \ && getline(".")[col(".") - 3] != '\'
    return "\<Del>\<BS>"
  endif
endfunction
" }}}

" helpers {{{
function s:AreQuotes(open, close)
  if a:open ==# a:close
    return 1
  endif
  return 0
endfunction

function s:IsString(line, col)
  if s:GetSHL(a:line, a:col) =~? "string"
    return v:true
  endif
endfunction

function s:IsComment(line, col)
  if s:GetSHL(a:line, a:col) =~? "comment"
    return v:true
  endif
  if col(".") == col("$")
        \ && !getline(line("."))[col(".") - 1]
        \ && s:GetSHL(a:line, col(".") - 1) =~? "comment"
    return v:true
  endif
endfunction

function s:IsEscaped()
  if getline(".")[col(".") - 2] == '\'
    return v:true
  endif
endfunction

function s:IsBeforeOrInsideWord()
  if col(".") == col("$")
    return v:false
  endif
  let pattern = '\s'
  for [open, close] in b:pairs
    if open != close
      let pattern = pattern.'\|'.s:Escape(close)
    endif
  endfor
  if getline(".")[col(".") - 1] =~ pattern.'\|[,;]'
    return v:false
  endif
  return v:true
endfunction

function s:IsArrowOrGreaterLessSign(c, lnum, index)
  if a:c != '<' && a:c != '>'
    return
  endif
  let line = getline(a:lnum)
  if strpart(line, a:index - 1, 2)  =~ '^[-=]>$'
    return v:true
  elseif strpart(line, a:index, 2)  =~ '^[<>]=$'
    return v:true
  elseif match(line, '^\s\=[<>]\s\=\(-\=\d\|\w\)', a:index - 1) > -1
    return v:true
  endif
endfunction

function s:GetLineBoundary(direction)
  if exists("g:coBraFullBuffer")
    if a:direction == 'f'
      return line("$")
    else
      return 1
    endif
  endif
  if !exists("g:coBraLineMax") || g:coBraLineMax <= 0
    if a:direction == 'f'
      return line("w$")
    else
      return line("w0")
    endif
  endif
  if a:direction == 'f'
    let boundary = line(".") + g:coBraLineMax - 1
    if boundary > line("$")
      return line("$")
    else
      return boundary
    endif
  endif
  if a:direction == 'b'
    let boundary = line(".") - g:coBraLineMax + 1
    if boundary < 1
      return 1
    else
      return boundary
    endif
  endif
endfunction

function s:Escape(str)
  return escape(a:str, '[]')
endfunction

function s:GetSHL(line, col)
  return synIDattr(synIDtrans(synID(a:line, a:col, 0)), "name")
endfunction
" }}}

let &cpo = s:save_cpo
unlet s:save_cpo
" }}}
