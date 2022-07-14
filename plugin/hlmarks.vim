"
" Guards.
" ______________________________________________________________________________
" ''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

if exists('g:loaded_hlmarks') && g:loaded_hlmarks
  finish
endif

" Check version.
if v:version < 800
  finish
endif

" Preserve 'cpoptions'.
let s:save_cpo = &cpo
set cpo&vim

"
" Configurations.
" ______________________________________________________________________________
" ''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

" All marks for debug.
" 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.''`^<>[]{}()"'
let s:default_marks = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
let s:default_hl = "ctermfg=255 ctermbg=39 cterm=bold guifg=#eeeeee guibg=#00afff gui=bold"

" Whether this plugin is activated or not in boot.
let g:hlmarks_activate_on_boot      = get(g:, 'hlmarks_activate_on_boot', 1)

" Mark characters that are displayed in gutter.
" Order in this sequence indicates 'stacking order' on same line.(only when
" sort option is enabled)
" Marks in left-side are placed lower, right-side is placed upper.
" e.g. 'ABCabc'
"   [bottom] A->B->C->a->b->c [top] (When they are placed on same line)
"   ..and so, mark-'A'~'b' is hid by mark-'c'.
" Note: This value do NOT avoid to invoke ANY commands for MARKS.
let g:hlmarks_displaying_marks      = get(g:, 'hlmarks_displaying_marks', s:default_marks)

" Whether sort signs for marks or not.
let g:hlmarks_sort_stacked_signs    = get(g:, 'hlmarks_sort_stacked_signs', 1)

" Cases that sign of marks is supressed to display.
"  h|H:help, q|Q:Quickfix, p|P:preview-window, r|R:read-only, m|M:modifiable
" Note: This value do NOT avoid to invoke ANY commands for MARKS.
let g:hlmarks_ignore_buffer_type    = get(g:, 'hlmarks_ignore_buffer_type', 'hq')

" Use default key mappings or not.
let g:hlmarks_use_default_key_maps  = get(g:, 'hlmarks_use_default_key_maps', 1)

" Prefix key for default key mappings.
let g:hlmarks_prefix_key            = get(g:, 'hlmarks_prefix_key', '<Leader>')

" Keymapping for native mark command. (no need to change until you need)
let g:hlmarks_alias_native_mark_cmd = get(g:, 'hlmarks_alias_native_mark_cmd', '\sm')

" Prefix for plugin command. (no need to change until you need)
let g:hlmarks_command_prefix        = get(g:, 'hlmarks_command_prefix', 'HlMarks')

" Group name for autocmd. (no need to change until you need)
let g:hlmarks_autocmd_group         = get(g:, 'hlmarks_autocmd_group', 'HlMarks')

" Timer interval for updating sign with ms.
let g:hlmarks_update_sign_interval  = get(g:, 'hlmarks_update_sign_interval', 2000)

" Stacking order type of signs for marks(by this plugin) and others.
" Signs of marks are ..
"   0: always bottom  /  1: as-is  /  2: always top
" .. on same line.
let g:hlmarks_stacked_signs_order   = get(g:, 'hlmarks_stacked_signs_order', 0)

" Format of mark characters in gutter by each character-class.
" '%m' is replaced to mark name('a', '[', etc), and format should be within 2chars=3bytes.
let g:hlmarks_sign_format_lower     = get(g:, 'hlmarks_sign_format_lower',  '%m>')
let g:hlmarks_sign_format_upper     = get(g:, 'hlmarks_sign_format_upper',  '%m>')
let g:hlmarks_sign_format_number    = get(g:, 'hlmarks_sign_format_number', '%m>')
let g:hlmarks_sign_format_symbol    = get(g:, 'hlmarks_sign_format_symbol', '%m>')

" Highlight format of marked line by each character-class.
let g:hlmarks_sign_linehl_lower     = get(g:, 'hlmarks_sign_linehl_lower',  s:default_hl)
let g:hlmarks_sign_linehl_upper     = get(g:, 'hlmarks_sign_linehl_upper',  s:default_hl)
let g:hlmarks_sign_linehl_number    = get(g:, 'hlmarks_sign_linehl_number', s:default_hl)
let g:hlmarks_sign_linehl_symbol    = get(g:, 'hlmarks_sign_linehl_symbol', s:default_hl)

" Highlight format of mark characters in gutter by each character-class.
let g:hlmarks_sign_gutterhl_lower   = get(g:, 'hlmarks_sign_gutterhl_lower',  s:default_hl)
let g:hlmarks_sign_gutterhl_upper   = get(g:, 'hlmarks_sign_gutterhl_upper',  s:default_hl)
let g:hlmarks_sign_gutterhl_number  = get(g:, 'hlmarks_sign_gutterhl_number', s:default_hl)
let g:hlmarks_sign_gutterhl_symbol  = get(g:, 'hlmarks_sign_gutterhl_symbol', s:default_hl)

"
" Key mapping interfaces.
" ______________________________________________________________________________
" ''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

nnoremap <silent><Plug>(hlmarks-activate)             :<C-u>call hlmarks#activate_plugin()<CR>
nnoremap <silent><Plug>(hlmarks-inactivate)           :<C-u>call hlmarks#inactivate_plugin()<CR>
nnoremap <silent><Plug>(hlmarks-reload)               :<C-u>call hlmarks#reload_plugin()<CR>
nnoremap <silent><Plug>(hlmarks-refresh-signs)        :<C-u>call hlmarks#refresh_signs()<CR>
nnoremap <silent><Plug>(hlmarks-automark)             :<C-u>call hlmarks#set_automark(1)<CR>
nnoremap <silent><Plug>(hlmarks-automark-global)      :<C-u>call hlmarks#set_automark(0)<CR>
nnoremap <silent><Plug>(hlmarks-remove-marks-line)    :<C-u>call hlmarks#remove_marks_on_line()<CR>
nnoremap <silent><Plug>(hlmarks-remove-marks-buffer)  :<C-u>call hlmarks#remove_marks_on_buffer()<CR>

"
" Completion.
" ______________________________________________________________________________
" ''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

if g:hlmarks_activate_on_boot
  silent! execute printf('augroup %s', g:hlmarks_autocmd_group)
    autocmd!
    autocmd VimEnter * call hlmarks#activate_plugin()
  augroup END
endif

" Plugin is loaded.
let g:loaded_hlmarks = 1

" Restore 'cpoptions'
let &cpo = s:save_cpo
unlet s:save_cpo
