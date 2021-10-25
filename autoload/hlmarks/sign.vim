scriptencoding utf-8
 
" Preserve 'cpoptions'
let s:save_cpo = &cpo
set cpo&vim


" ==============================================================================
" Sign
" ==============================================================================
" ''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

let s:sign = {
  \ 'prefix': 'HighlightMarks_',
  \ 'mark_specifier': '%m',
  \ 'cache_name': 'signs',
  \ 'chars_classes': ['lower', 'upper', 'number', 'symbol'],
  \ 'chars_class_pattern': {
  \   'lower':  '\v\L+',
  \   'upper':  '\v\U+',
  \   'number': '\v\D+',
  \   'symbol': '\v[^.''`\^<>[\]{}()"]'
  \ },
  \ 'escape_chars': '.''`^<>[]{}()"'
  \ }

function! s:_export_()
  return s:
endfunction

"
" [For testing] Get SID of this file.
"
function! hlmarks#sign#sid()
  return maparg('<SID>', 'n')
endfunction
nnoremap <SID>  <SID>

"
" [For testing] Get local variables in this file.
"
function! hlmarks#sign#scope()
  return s:
endfunction

"
" Public.
" ______________________________________________________________________________
" ''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

"
" Define signs.
"
function! hlmarks#sign#define()
  let mark_specifier = s:sign.mark_specifier
  for mark_type in s:sign.chars_classes
    let mark_bundle = s:extract_chars(mark_type, g:hlmarks_displaying_marks)

    if empty(mark_bundle)
      continue
    endif

    let sign_format = s:fix_sign_format({'g:hlmarks_sign_format_' . mark_type}, mark_specifier)

    let line_hl = s:sign.prefix . 'L_' . mark_type
    let gutter_hl = s:sign.prefix . 'G_' . mark_type

    silent! execute printf('highlight default %s %s',
      \ line_hl,
      \ {'g:hlmarks_sign_linehl_' . mark_type}
      \ )
    silent! execute printf('highlight default %s %s',
      \ gutter_hl,
      \ {'g:hlmarks_sign_gutterhl_' . mark_type}
      \ )

    let last_idx = strlen(mark_bundle) - 1
    for idx in range(0, last_idx)
      let mark_name = mark_bundle[idx : idx]
      silent! execute printf('sign define %s linehl=%s text=%s texthl=%s',
        \ s:sign_name_of(mark_name),
        \ line_hl,
        \ substitute(sign_format, mark_specifier, mark_name, ''),
        \ gutter_hl
        \ )
    endfor
  endfor
endfunction

"
" Generate sign state.
"
" Retrun: [Dict] sign state (see extract_sign_specs()) 
" Note:   No need to reorder because signs are already ordered when mark is set.
"
function! hlmarks#sign#generate_state()
  return s:extract_sign_specs(
    \ s:sign_bundle(),
    \ 0,
    \ s:sign_pattern()
    \ )
endfunction

"
" Get sign state cache.
"
" Return: [Dict] cache (see generate_state())
"
function! hlmarks#sign#get_cache()
  return hlmarks#cache#get(s:sign.cache_name, {})
endfunction

"
" Place new sign.
"
" Param:  [Number] line_no: line number
" Param:  [String] mark_name: mark name
"
function! hlmarks#sign#place_on_mark(line_no, mark_name)
  let sign_units = [[s:generate_id(), s:sign_name_of(a:mark_name)]]

  if !(g:hlmarks_stacked_signs_order == 1 && g:hlmarks_sort_stacked_signs == 0)
    let sign_spec = s:extract_sign_specs(
      \ s:sign_bundle(),
      \ a:line_no,
      \ s:sign_pattern()
      \ )

    " Note: No need to add to 'all(comparing)', because new signs are not placed yet.
    " Note: No need to add to 'ids(removing)', because no need to remove new signs.
    call extend(sign_spec.marks, sign_units)

    let sign_spec = s:reorder_spec(sign_spec)

    " Note: In this case of adding new sign, signs are surely re-oredered.
    call s:remove_with_ids(sign_spec.ids, bufnr('%'))
    let sign_units = sign_spec.ordered

  endif

  call s:place(a:line_no, sign_units)
endfunction

"
" Place signs according to delta.
"
" Param:  [Dict] (a:1) sign specs (past)
" Param:  [Dict] (a:2) sign specs (current)
"
function! hlmarks#sign#place_with_delta(...)
  let cache = a:0 ? a:1 : hlmarks#sign#get_cache()
  let snapshot = a:0 >= 2 ? a:2 : hlmarks#sign#generate_state()

  for [line_no, spec] in items(snapshot)
    if !has_key(cache, line_no) || spec != cache[line_no]
      let ordered_spec = s:reorder_spec(spec)
      call s:remove_with_ids(ordered_spec.ids, bufnr('%'))
      call s:place(line_no, ordered_spec.ordered)
    endif
  endfor
endfunction

"
" Remove all signs of mark in designated buffer.
"
" Param:  [List] (a:1) target buffer numbers(default=['%'])
"
function! hlmarks#sign#remove_all(...)
  let buffer_numbers = a:0 ? a:1 : [bufnr('%')]
  for buffer_no in buffer_numbers
    let bundle = s:sign_bundle(buffer_no)
    let sign_ids = s:extract_sign_ids(bundle, s:sign_pattern())
    call s:remove_with_ids(sign_ids, buffer_no)
  endfor
endfunction

"
" Remove sign of marks that is linked to designated mark.
"
" Param:  [String] mark_name: character as mark name
" Param:  [Number] (a:1) target buffer number(default='%')
"
function! hlmarks#sign#remove_on_mark(mark_name, ...)
  let buffer_no = a:0 ? a:1 : bufnr('%')
  let bundle = s:sign_bundle(buffer_no)
  let sign_name = '\C\v^' . s:sign_name_of(escape(a:mark_name, s:sign.escape_chars)) . '$'
  let sign_ids = s:extract_sign_ids(bundle, sign_name)
  call s:remove_with_ids(sign_ids, buffer_no)
endfunction

"
" Determine whether current buffer state/type is valid for placing sign or not.
"
" Return: [Number] determination(0/1)
"
function! hlmarks#sign#should_place()
  let ignore_buffer_type = g:hlmarks_ignore_buffer_type
  return (match(ignore_buffer_type, '\ch') >= 0 && &buftype    ==? 'help'    )
    \ || (match(ignore_buffer_type, '\cq') >= 0 && &buftype    ==? 'quickfix')
    \ || (match(ignore_buffer_type, '\cp') >= 0 && &pvw        ==  1         )
    \ || (match(ignore_buffer_type, '\cr') >= 0 && &readonly   ==  1         )
    \ || (match(ignore_buffer_type, '\cm') >= 0 && &modifiable ==  0         )
    \ ? 0 : 1
endfunction

"
" Set sign state cache.
"
" Param:  [Dict] (a:1) cache(default=generate_state())
"
function! hlmarks#sign#set_cache(...)
  call hlmarks#cache#set(s:sign.cache_name, (a:0 ? a:1 : hlmarks#sign#generate_state()))
endfunction

"
" Remove sign definitions.
"
function! hlmarks#sign#undefine()
  let defined_names = s:extract_definition_names(s:definition_bundle(), s:sign_pattern())
  for sign_name in defined_names
    silent! execute printf('sign undefine %s', sign_name)
  endfor
endfunction

"
" Private.
" ______________________________________________________________________________
" ''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

"
" Get strings of sign definitions.
"
" Return: [String] bundle that contains sign definitions
"
function! s:definition_bundle()
  redir => bundle
    silent! sign list
  redir END

  return bundle
endfunction

"
" Extract characters that match designated character-class.
"
" Param:  [String] class_name: character-class name
" Param:  [String] bundle: source strings
" Return: [String] extracted characters
"
function! s:extract_chars(class_name, bundle)
  return substitute(a:bundle, s:sign.chars_class_pattern[a:class_name], '', 'g')
endfunction

"
" Extract sign names from bundle that is taken from 'sign list' command.
"
" Param:  [String] bundle: bundle of sign definitions
" Param:  [String] pattern: pattern that matches name
" Return: [List] list of definition names
"
function! s:extract_definition_names(bundle, pattern)
  let defined_names = []

  for crumb in split(a:bundle, "\n")
    let splited = split(crumb, '\v\s+')
    if len(splited) >= 2 && match(splited[1], a:pattern) >= 0
      call add(defined_names, splited[1])
    endif
  endfor

  return defined_names
endfunction

"
" Extract sign id from bundle that is taken from 'sign place' command.
"
" Param:  [String] bundle: bundle of placed signs
" Param:  [String] pattern: pattern that matches name
" Return: [List] list of extracted sign id
" Note:   Duplication of id is considered.
"
function! s:extract_sign_ids(bundle, pattern)
  let sign_ids = []

  for crumb in split(a:bundle, "\n")
    if stridx(crumb, '=') < 0
      continue
    endif

    let matched = matchlist(crumb, '\v^\s+\S+\=(\d+)\s+\S+\=(\d+)\s+\S+\=(\S+)$')
    if !empty(matched) && match(matched[3], a:pattern) >= 0
      call add(sign_ids, str2nr(matched[2], 10))
    endif
  endfor

  return sign_ids
endfunction

"
" Extract sign spec(s) from bundle that is taken from 'sign place' command.
"
" Param:  [String] bundle: bundle of placed signs
" Param:  [Number] line_no: number of target line
"                           (If pased '0', returns sign specs for all lines)
" Param:  [String] pattern: pattern that matches name as mark's
" Return: [Dict] dictionary of extracted sign spec(s) as following structure
"          Note that values in all keys are ordered OLD->NEW order.
"          (FYI) In result of 'sign place..' command, ordered NEW->OLD.
"          <line_no != 0>
"           { 'marks':  [[id,name], ..] => sign units as mark's sign
"             'others': (same sa above) => sign units as other's sign
"             'ids':    [id, id, ..]    => all id of signs
"             'order':  [n, n, ..]      => order list by sign type,
"                                          n = 1(mark's) or 0 (other's) }
"          <line_no = 0>
"           { 'line_no': { spec same as above }, .. }
" Note:   Duplication of id is considered.
"
function! s:extract_sign_specs(bundle, line_no, pattern)
  let sign_specs = {}
  let sign_spec = {
    \ 'marks': [],
    \ 'others': [],
    \ 'ids': [],
    \ 'order': []
    \ }

  for crumb in split(a:bundle, "\n")
    if stridx(crumb, '=') < 0
      continue
    endif

    let matched = matchlist(crumb, '\v^\s+\S+\=(\d+)\s+\S+\=(\d+)\s+\S+\=(\S+)$')
    if empty(matched) || (a:line_no != 0 && matched[1] != a:line_no)
      continue
    endif

    let line_no = matched[1]
    let sign_id = str2nr(matched[2], 10)
    let sign = [sign_id, matched[3]]

    if !has_key(sign_specs, line_no)
      let sign_specs[line_no] = deepcopy(sign_spec, 1)
    endif

    if match(matched[3], a:pattern) >= 0
      call insert(sign_specs[line_no].marks, sign)
      call insert(sign_specs[line_no].order, 1)
    else
      call insert(sign_specs[line_no].others, sign)
      call insert(sign_specs[line_no].order, 0)
    endif

    call insert(sign_specs[line_no].ids, sign_id)
  endfor

  return a:line_no == 0
    \ ? sign_specs
    \ : (has_key(sign_specs, a:line_no) ? sign_specs[a:line_no] : sign_spec)
endfunction

"
" Fix format strins for sign definition.
"
" Param:  [String] format: format string
" Param:  [String] specifier: specifier of mark
" Return: [String] fixed format
" Rules:  1. Format length is 2byte.
"         2. Exceeded characters are snipped backward.
"         3. Only one mark specifier must be in format.
"         4. Specifier is added to front if not exist.
"
function! s:fix_sign_format(format, specifier)
  let escaped_specifier = escape(a:specifier, '%')
  let format = substitute(a:format, '\v(' . escaped_specifier . ')+', a:specifier, 'g')
  let splited = split(format, '\v' . escaped_specifier, 1)
  let crumb_count = len(splited)

  " Snip over parts(format has two or more single specifiers).
  if crumb_count >= 3
    call remove(splited, 2, -1)
    let crumb_count = 2
  endif

  " No specifiers.
  if crumb_count == 1
    return a:specifier . format[0:0]

  " Contains one specifier.
  elseif crumb_count == 2
    let head = splited[0][0:0]
    return head . a:specifier . (strlen(head) == 0 ? splited[1][0:0] : '')

  " Fallback(since split with 'keepempty' flag, never arrive in this point).
  else
    return a:specifier
  endif
endfunction

"
" Generate sign id for current buffer.
"
" Return: [Number] sign id
" Note:   Don't use sort() without sort-funtion for sorting numbers.
"         And it's is very slow.
"
function! s:generate_id()
  let bundle = s:sign_bundle()
  let sign_ids = s:extract_sign_ids(bundle, '')
  let id = empty(sign_ids) ? 1 : max(sign_ids) + 1

  " Reuse lower id.
  if id > 100000
    " http://vim-jp.org/vim-users-jp/2009/11/05/Hack-98.html
    if has('reltime')
      let match_end = matchend(reltimestr(reltime()), '\v\d+\.') + 1
      let rand = reltimestr(reltime())[match_end : ] % (100000 + 1)
      if index(sign_ids, rand) < 0
        let id = rand
      endif
    endif
  endif

  return id
endfunction

"
" Convert sign name to mark name.
"
" Param:  [String] sign_name: sign name
" Return: [String] mark name
"
function! s:mark_name_of(sign_name)
  return substitute(a:sign_name, s:sign.prefix, '', '')
endfunction

"
" (Sorter function) Sort sign names with defined order.
"
" Param:  [List] a:,b: sign unit([id, name])
" Return: [Number] sort result
" Note:   This sort function is used with following dictionary.
"          { 'seq': [String] sequence of character that indicates sort order }
"
function! s:name_sorter(a, b) dict
  let a_idx = stridx(self.seq, s:mark_name_of(a:a[1]))
  let b_idx = stridx(self.seq, s:mark_name_of(a:b[1]))

  return a_idx < b_idx ? -1 : (a_idx > b_idx ? 1 : 0)
endfunction

"
" Place signs.
"
" Param:  [Number] line_no: line no.
" Param:  [List] sign_units: sign units([[id, name], ..])
"
function! s:place(line_no, sign_units)
  let buffer_no = bufnr('%')
  for [sign_id, sign_name] in a:sign_units
    " Note: Suppress errors for unloaded/deleted buffer related to A-Z0-9 marks.
    silent! execute printf('sign place %s line=%s name=%s buffer=%s',
      \ sign_id,
      \ a:line_no,
      \ sign_name,
      \ buffer_no
      \ )
  endfor
endfunction

"
" Remove signs with designated id(s).
"
" Param:  [List] sign_ids: sign id's
" Param:  [Number] (a:1) target buffer number(default='%')
"
function! s:remove_with_ids(sign_ids, ...)
  let buffer_no = a:0 ? a:1 : bufnr('%')
  for id in a:sign_ids
    " Note: Suppress errors for unloaded/deleted buffer related to A-Z0-9 marks.
    silent! execute printf('sign unplace %s buffer=%s', id, buffer_no)
  endfor
endfunction

"
" Reorder sign spec.
"
" Param:  [Dict] sign_spec: sign spec(see extract_sign_specs())
" Return: [Dict] dictionary of re-ordered sign spec as following structure
"           { ... Same as return value of extract_sign_specs() ...
"             'ordered':  [[id,name], ..] => ordered sign units }
" Note:   This function is frequently called.
"
function! s:reorder_spec(sign_spec)
  let sign_spec = a:sign_spec

  " Note: Sorter function changes passed list(In this case, sign_spec.marks).
  if g:hlmarks_sort_stacked_signs != 0
    call sort(sign_spec.marks, 's:name_sorter', {
      \ 'seq': g:hlmarks_displaying_marks,
      \ })
  endif

  " 0: Signs of mark are always placed lower than others.
  if g:hlmarks_stacked_signs_order == 0
    let signs = sign_spec.marks + sign_spec.others

  " 1: Signs of mark are sorted but related-position to other signs is as-is.
  elseif g:hlmarks_stacked_signs_order == 1
    let signs = []
    for sign_type in sign_spec.order
      if sign_type == 1
        call add(signs, remove(sign_spec.marks, 0))
      else
        call add(signs, remove(sign_spec.others, 0))
      endif
    endfor
    call extend(signs, sign_spec.marks)

  " 2: Signs of mark are always placed upper than others.
  else
    let signs = sign_spec.others + sign_spec.marks
  endif

  let sign_spec.ordered = signs

  return sign_spec
endfunction

"
" Get strings of placed signs.
"
" Params: [Number] buffer_no: target buffer number
" Return: [String] bundle that contains placed signs
" Note:   Bundle has format as follows.
"           - Data line format:
"               ^\s+(Line-No=NO)\s+(Id=ID)\s+(Name=NAME)\s+(Other=VALUE)*$
"           - Grouped by each line-no.
"           - In group of line-no, ordered by 'placed last->first'.
"
function! s:sign_bundle(...)
  let buffer_no = a:0 ? a:1 : bufnr('%')
  redir => bundle
    " Note: Suppress errors for unloaded/deleted buffer related to A-Z0-9 marks.
    silent! execute printf('sign place buffer=%s', buffer_no)
  redir END

  return bundle
endfunction

"
" Convert mark name to sign name
"
" Param:  [String] mark_name: mark name
" Return: [String] sign name
"
function! s:sign_name_of(mark_name)
  return s:sign.prefix . a:mark_name
endfunction

"
" Get search pattern with sign.
"
" Return: [String] pattern
"
function! s:sign_pattern()
  return '\C^' . s:sign.prefix
endfunction


" Restore 'cpoptions'
let &cpo = s:save_cpo
unlet s:save_cpo
