" coBra
"
" for [c]oerced [b]racket
" author Pierre Dommerc
" dommerc.pierre@gmail.com
" MIT

" script {{{

let s:save_cpo = &cpo
set cpo&vim

if exists("g:coBra")
  finish
endif
let g:coBra = 1

if !exists("g:coBraPairs")
  let g:coBraPairs = [
        \  ['"', '"'],
        \  ["'", "'"],
        \  ['`', '`'],
        \  ['{', '}'],
        \  ['(', ')'],
        \  ['[', ']']
        \]
endif

if !exists("g:coBraMaxPendingCloseTry")
  let g:coBraMaxPendingCloseTry = 10
endif

let s:recursiveCount = 0

for [open, close] in g:coBraPairs
  if open != close
    execute 'inoremap <expr><silent> ' . open . ' <SID>AutoClose("' . escape(open, '"') . '", "' . escape(close, '"') . '")'
    execute 'inoremap <expr><silent> ' . close . ' <SID>SkipClose("' . escape(open, '"') . '", "' . escape(close, '"') . '")'
  else
    execute 'inoremap <expr><silent> ' . open . ' <SID>ManageQuote("' . escape(open, '"') . '")'
  endif
endfor

inoremap <expr> <BS> <SID>AutoDelete()

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
        \ && searchpair(escape(a:open, '['),
        \ '',
        \ escape(a:close, ']'),
        \ 'cnW',
        \ 's:IsString(line("."), col(".")) || s:IsComment(line("."), col("."))',
        \ s:GetLineBoundary('f')) > 0
    return "\<Right>"
  endif
  return a:close
endfunction

" pending close {{{
function s:IsPendingClose(open, close)
  if a:open == a:close
    return
  endif
  let currentLine = line(".")
  let currentCol = col(".")
  let s:recursiveCount = 0
  let result = s:RecursiveSearch(a:open, a:close, s:GetLineBoundary('f'), s:GetLineBoundary('b'))
  call cursor(currentLine, currentCol)
  return result
endfunction

function s:RecursiveSearch(open, close, maxForward, maxBackward)
  if s:recursiveCount >= &maxfuncdepth - 10 || s:recursiveCount >= g:coBraMaxPendingCloseTry
    return
  endif
  let s:recursiveCount = s:recursiveCount + 1
  let [line, col] = searchpos(escape(a:close, ']'), 'eWz', a:maxForward)
  if line == 0 && col == 0
    return
  endif
  if s:IsString(line, col) || s:IsComment(line, col)
    return s:RecursiveSearch(a:open, a:close, a:maxForward, a:maxBackward)
  endif
  let [pairLine, pairCol] = searchpairpos(escape(a:open, '['),
        \ '',
        \ escape(a:close, ']'),
        \ 'bnW',
        \ 's:IsString(line("."), col(".")) || s:IsComment(line("."), col("."))',
        \ a:maxBackward)
  if pairLine == 0 && pairCol == 0
    return v:true
  endif
  return s:RecursiveSearch(a:open, a:close, a:maxForward, a:maxBackward)
endfunction
" }}}

" auto delete {{{
function s:AutoDelete()
  for [open, close] in g:coBraPairs
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
    let [line, col] = searchpairpos(escape(a:open, '['),
          \ '',
          \ escape(a:close, ']'),
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
    if s:InBetweenValid(a:close, start, end)
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

function s:InBetweenValid(close, start, end)
  if a:start.line == a:end.line
    return s:OneLineCheck(a:close, a:start, a:end)
  endif
  if match(getline(a:start.line), '^\s*$', a:start.col - 1) == -1
    return v:false
  endif
  if a:start.line + 1 < a:end.line
    for row in getline(a:start.line + 1, a:end.line - 1)
      if match(row, '^\s*$') == -1
        return v:false
      endif
    endfor
  endif
  let lastLine = strpart(getline(a:end.line), 0, a:end.col)
  if match(lastLine, '^\s*'.escape(a:close, ']').'$') == -1
    return v:false
  endif
  return v:true
endfunction

function s:OneLineCheck(close, start, end)
  let line = strpart(getline(a:start.line), 0, a:end.col)
  if match(line, '^\s*'.escape(a:close, ']').'$', a:start.col - 1) == -1
    return v:false
  else
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
  for [open, close] in g:coBraPairs
    if open != close
      let pattern = pattern.'\|'.escape(close, ']')
    endif
  endfor
  if getline(".")[col(".") - 1] =~ pattern.'\|[,;]'
    return v:false
  endif
  return v:true
endfunction

function s:GetLineBoundary(direction)
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

function s:GetSHL(line, col)
  return synIDattr(synIDtrans(synID(a:line, a:col, 0)), "name")
endfunction
" }}}

let &cpo = s:save_cpo
unlet s:save_cpo
" }}}
