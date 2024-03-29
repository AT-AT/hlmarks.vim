scriptencoding utf-8
 
" Preserve 'cpoptions'
let s:save_cpo = &cpo
set cpo&vim


" ==============================================================================
" Plugin
" ==============================================================================
" ''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

let s:plugin = {
  \ 'activated': 0,
  \ 'preserved': {
  \   'hlmarks_prefix_key': '',
  \   'hlmarks_alias_native_mark_cmd': '',
  \   'hlmarks_command_prefix': '',
  \   'hlmarks_autocmd_group': ''
  \ },
  \ 'timer': 0
  \ }

function! s:_export_()
  return s:
endfunction

"
" [For testing] Get SID of this file.
"
function! hlmarks#sid()
  return maparg('<SID>', 'n')
endfunction
nnoremap <SID>  <SID>

"
" [For testing] Get local variables in this file.
"
function! hlmarks#scope()
  return s:
endfunction

"
" Public.
" ______________________________________________________________________________
" ''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

"
" Activate plugin.
"
function! hlmarks#activate_plugin()
  if s:plugin.is_active()
    return
  endif

  call s:preserve_definition_keyword()
  call hlmarks#sign#define()
  call hlmarks#refresh_signs()
  call s:toggle_key_mappings(1)
  call s:toggle_usercmd(1)
  call s:toggle_autocmd(1)
  call s:toggle_timer(1)

  call s:plugin.activate()
endfunction

"
" Inctivate plugin.
"
function! hlmarks#inactivate_plugin()
  if !s:plugin.is_active()
    return
  endif

  call s:toggle_timer(0)
  call s:toggle_autocmd(0)
  call s:toggle_usercmd(0)
  call s:toggle_key_mappings(0)
  call s:sweep_out()

  call s:plugin.inactivate()
endfunction

"
" Reload plugin.
"
function! hlmarks#reload_plugin()
  call hlmarks#inactivate_plugin()
  call hlmarks#activate_plugin()
endfunction

"
" Force to refresh signs with latest state in current buffer.
"
" Note:   This function refreshes current buffer ONLY.
"         Other buffers will be refreshed by autocmd.
"         Test cases (use all marks)
"         1) open new buffer  2) open file          3) open hidden file again
"         4) go another tab   5) load buffer by cmd 6) split same buffer
"         7) split and new    8) load by read cmd   9) after 'changed' alert 
"
function! hlmarks#refresh_signs()
  call hlmarks#sign#remove_all()

  if hlmarks#sign#should_place()
    for [mark, line_no] in items(hlmarks#mark#specs_for_sign())
      call hlmarks#sign#place_on_mark(line_no, mark)
    endfor
  endif

  call hlmarks#mark#set_cache()
  call hlmarks#sign#set_cache()
endfunction

"
" Remove marks on current buffer.
"
function! hlmarks#remove_marks_on_buffer()
  call hlmarks#sign#remove_all()
  call hlmarks#mark#remove_all()

  call hlmarks#sign#set_cache()
  call hlmarks#mark#set_cache()
endfunction

"
" Remove marks on current line.
"
function! hlmarks#remove_marks_on_line()
  for mark in hlmarks#mark#remove_on_line()
    call hlmarks#sign#remove_on_mark(mark)
  endfor

  call hlmarks#sign#set_cache()
  call hlmarks#mark#set_cache()
endfunction

"
" Set local/global mark that is generated by automatically.
"
" Param:  [Number] local_mark: whether generate mark for locals or not(=globals)
" Param:  [Number] (a:1) line no.(default='.')
"
function! hlmarks#set_automark(local_mark, ...)
  let mark = hlmarks#mark#generate_name(a:local_mark ? 1 : 0)
  let line_no = a:0 ? a:1 : line('.')
  call hlmarks#set_mark(mark, line_no)
endfunction!

"
" Set mark.
"
" Param:  [String] mark: mark name
" Param:  [Number] (a:1) line no.(default='.')
" Note:   This function delegates placing sign process to hlmarks#refresh_signs().
"         If process of here becomes heavy, consider that place/update sign in each case.
"         Mark should be handled as below.
"           In togglable(s:mark.togglables in mark.vim)  => toggle
"           In g:hlmarks_displaying_marks                => sign(even if not togglable)
"
function! hlmarks#set_mark(mark, ...)
  let [target_line_no, pos] = [line('.'), []]
  if a:0 && a:1 != target_line_no
    let [target_line_no, pos] = [a:1, getpos('.')]
  endif

  if !empty(pos)
    call cursor(target_line_no, 1)
  endif

  let [buffer_no, mark_line_no] = hlmarks#mark#pos(a:mark)

  " Case : Toggle = togglable mark, already on same line.
  if hlmarks#mark#should_handle(a:mark) && mark_line_no == target_line_no && buffer_no == bufnr('%')

    " Remove mark whether it can be removed or not.
    call hlmarks#mark#remove(a:mark)

  " Case : Delegate = un-togglable mark.
  " Case : Move = already in same buffer or used in other buffer(globals).
  " Case : Set = not yet anywhere.
  else
    call hlmarks#mark#set(a:mark)
  endif

  call hlmarks#refresh_signs()

  if !empty(pos)
    call setpos('.', pos)
  endif
endfunction

"
" Private.
" ______________________________________________________________________________
" ''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

"
" Set flag to active.
"
function! s:plugin.activate()
  let self.activated = 1
endfunction

"
" Set flag to inactive.
"
function! s:plugin.inactivate()
  let self.activated = 0
endfunction

"
" Determine plugin is active or not.
"
" Return: [Number] determination(0/1)
"
function! s:plugin.is_active()
  return self.activated == 1
endfunction

"
" Preserve global variable that is used for some key/name/prefix in definition.
"
function! s:preserve_definition_keyword()
  let target = keys(s:plugin.preserved)
  for target_name in target
    let s:plugin.preserved[target_name] = get(g:, target_name, '')
  endfor
endfunction

"
" Sweep out various related data.
"
function! s:sweep_out()
  let buffer_numbers = hlmarks#buffer#numbers()

  call hlmarks#sign#remove_all(buffer_numbers)
  call hlmarks#cache#clean(buffer_numbers)
  call hlmarks#sign#undefine()
endfunction

"
" Toggle auto-command.
"
" Param:  [Any] flag: whether enable auto-cmd or not
"
function! s:toggle_autocmd(flag)
  silent! execute printf('augroup %s', g:hlmarks_autocmd_group)
    execute printf('autocmd! %s', s:plugin.preserved.hlmarks_autocmd_group)

    if a:flag
      autocmd BufEnter,FileChangedShellPost * call hlmarks#refresh_signs()
    endif
  augroup END
endfunction

"
" Toggle key mappings.
"
" Param:  [Any] flag: whether enable key-mappings or not
"
function! s:toggle_key_mappings(flag)
  let preserved_prefix_key = s:plugin.preserved.hlmarks_prefix_key

  silent! execute printf('unmap %s', s:plugin.preserved.hlmarks_alias_native_mark_cmd)
  silent! nunmap  m
  silent! execute printf('nunmap  %smr', preserved_prefix_key)
  silent! execute printf('nunmap  %smm', preserved_prefix_key)
  silent! execute printf('nunmap  %smM', preserved_prefix_key)
  silent! execute printf('nunmap  %sml', preserved_prefix_key)
  silent! execute printf('nunmap  %smb', preserved_prefix_key)

  if a:flag && g:hlmarks_use_default_key_maps

    " Define alias mapping of original mark command. 
    silent! execute printf('noremap <script><unique> %s m', g:hlmarks_alias_native_mark_cmd)

    " Change invocation function of original key.
    silent! nnoremap <silent><unique> m :call hlmarks#set_mark(nr2char(getchar()))<CR>

    silent! execute printf(
      \ 'nmap <silent><unique> %smr <Plug>(hlmarks-refresh-signs)', g:hlmarks_prefix_key)
    silent! execute printf(
      \ 'nmap <silent><unique> %smm <Plug>(hlmarks-automark)', g:hlmarks_prefix_key)
    silent! execute printf(
      \ 'nmap <silent><unique> %smM <Plug>(hlmarks-automark-global)', g:hlmarks_prefix_key)
    silent! execute printf(
      \ 'nmap <silent><unique> %sml <Plug>(hlmarks-remove-marks-line)', g:hlmarks_prefix_key)
    silent! execute printf(
      \ 'nmap <silent><unique> %smb <Plug>(hlmarks-remove-marks-buffer)', g:hlmarks_prefix_key)
  endif
endfunction

"
" Toggle timer.
"
" Param:  [Any] flag: whether enable timer or not
"
function! s:toggle_timer(flag)
  if a:flag
    let s:timer = timer_start(g:hlmarks_update_sign_interval, function('s:update_signs'), {'repeat': -1})
  else
    call timer_stop(s:timer)
  endif
endfunction

"
" Toggle user-command.
"
" Param:  [Any] flag: whether enable user-cmd or not
"
function! s:toggle_usercmd(flag)
  let preserved_prefix = s:plugin.preserved.hlmarks_command_prefix
  let prefix = g:hlmarks_command_prefix

  redir => bundle
    silent! execute printf('command %s', preserved_prefix)
  redir END

  for crumb in split(bundle, "\n")
    let matched = matchlist(crumb, '\v^\s+(' . preserved_prefix . '\S+)\s+.+$')
    if !empty(matched)
      silent! execute printf('delcommand %s', matched[1])
    endif
  endfor

  if a:flag
    silent! execute printf('command! %sOff call hlmarks#inactivate_plugin()', prefix)
    silent! execute printf('command! %sReload call hlmarks#reload_plugin()', prefix)
  else
    silent! execute printf('command! %sOn  call hlmarks#activate_plugin()', prefix)
  endif
endfunction

"
" Refresh signs with latest state in current buffer if needed.
"
" Note:   Update in following case.
"           Case1. Mark state is changed.
"             This case is caused by changing state of un-settable marks, other plugin
"             placed mark, user executes command directly, etc.
"             Note that calculating difference of mark state is complicated, so refresh all.
"           Case2. Only sign state is changed.
"             This case indicates that other plugin placed sign, user executes command, etc.
"             Note that sign cache has info of line that only contains sign placed by others.
"
function! s:update_signs(...)
  if !hlmarks#sign#should_place()
    return
  endif

  let mark_snapshot = hlmarks#mark#generate_state()
  let mark_cache = hlmarks#mark#get_cache()

  let sign_snapshot = hlmarks#sign#generate_state()
  let sign_cache = hlmarks#sign#get_cache()

  " Note: Leave echoes for further debug.

  if mark_snapshot != mark_cache
    call hlmarks#refresh_signs()
    " echo reltimestr(reltime()) . '(by change of marks)'
  elseif sign_snapshot != sign_cache
    call hlmarks#sign#place_with_delta(sign_cache, sign_snapshot)
    call hlmarks#sign#set_cache()
    " echo reltimestr(reltime()) . '(by change of signs)'
  else
    " echo reltimestr(reltime()) . '(no changes)'
  endif
endfunction


" Restore 'cpoptions'
let &cpo = s:save_cpo
unlet s:save_cpo
