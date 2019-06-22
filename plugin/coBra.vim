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
let b:pairs = g:defaultPairs

if !exists('g:coBraPairs')
  let g:coBraPairs = { 'default': g:defaultPairs }
elseif !has_key(g:coBraPairs, 'default')
  let g:coBraPairs.default = g:defaultPairs
endif

if !exists("g:coBraMaxPendingCloseTry")
  let g:coBraMaxPendingCloseTry = 10
endif

let s:recursiveCount = 0

augroup coBra
  autocmd!
  autocmd FileType * call s:Init()
augroup END

function s:Init()
  for type in keys(g:coBraPairs)
    if type == &filetype
      return s:setPairsAndMap(type)
    endif
  endfor
  return s:setPairsAndMap('default')
endfunction

function s:setPairsAndMap(type)
  let b:pairs = g:coBraPairs[a:type]
  for [open, close] in b:pairs
    if open != close
      execute 'inoremap <buffer><expr><silent> '.open.
            \' <SID>AutoClose("'.escape(open, '"').'", "'.escape(close, '"').'")'
      execute 'inoremap <buffer><expr><silent> '.close.
            \' <SID>SkipClose("'.escape(open, '"').'", "'.escape(close, '"').'")'
    else
      execute 'inoremap <buffer><expr><silent> '.open.' <SID>ManageQuote("'.escape(open, '"').'")'
    endif
  endfor
  inoremap <buffer><expr> <BS> <SID>AutoDelete()
  inoremap <buffer><expr> <CR> <SID>AutoBreak()
endfunction

function s:ManageQuote(quote)
  if s:IsString(line("."), col("."))
        \ && s:IsString(line("."), col(".") - 1)
        \ && getline(".")[col(".") - 1] == a:quote
        \ && !s:IsEscaped()
    return "\<Right>"
  endif
  return s:AutoClose(a:quote, a:quote)
endfunction

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
