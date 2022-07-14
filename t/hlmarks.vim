execute 'source ' . expand('%:p:h') . '/t/_common/test_helpers.vim'
execute 'source ' . expand('%:p:h') . '/t/_common/local_helpers.vim'

runtime! plugin/hlmarks.vim

call vspec#hint({'scope': 'hlmarks#scope()', 'sid': 'hlmarks#sid()'})

let s:script_val = Create_Script_Val_Handler('s:plugin')



function! s:expect_usercmd(cmds, prefix)
  let bundle = _Grab_('command')
  let extracted = []
  for crumb in bundle
    if crumb =~# '\v\s+'.a:prefix
      call add(extracted, crumb)
    endif
  endfor

  let matched = 0
  for name in a:cmds
    for crumb in extracted
      if crumb =~# '\v\s+'.a:prefix.name.'\s+'
        let matched += 1
      endif
    endfor
  endfor
  Expect len(extracted) == len(a:cmds)
  Expect matched == len(a:cmds)
endfunction


function! s:expect_sign_defs(active)
  let bundle = _Grab_('sign list')
  let extracted = []
  for crumb in bundle
    if stridx(crumb, 'HighlightMarks_') >= 0
      call add(extracted, crumb)
    endif
  endfor

  if a:active
    Expect len(extracted) == len(split(g:hlmarks_displaying_marks, '\zs'))
  else
    Expect empty(extracted) to_be_true
  endif
endfunction


function! s:expect_keymap(active, prefix, alias)
  let extracted = []

  let bundle = _Grab_('map')
" Expect bundle == []
  for crumb in bundle
    if crumb =~# '\v^n.+'.escape(a:prefix, '\<>').'m(r|m|M|l|b)\s+\<Plug\>\(hlmarks-.+\)'
      call add(extracted, crumb)
    endif
  endfor

  let bundle = _Grab_('map m')
  for crumb in bundle
    if crumb =~# '\v^n\s+m\s+.+:call hlmarks#set_mark\(nr2char\(getchar\(\)\)\)\<CR\>'
      call add(extracted, crumb)
    endif
  endfor

  let bundle = _Grab_('map '.a:alias)
  for crumb in bundle
    if crumb =~# '\v^\s+'.escape(a:alias, '\').'\s+\&\s+m$'
      call add(extracted, crumb)
    endif
  endfor

  if a:active
    Expect len(extracted) == 7
  else
    Expect empty(extracted) to_be_true
  endif
endfunction


function! s:expect_autocmd(active, group)
  let bundle = _Grab_('autocmd '.a:group)
  let extracted = []
  for crumb in bundle
    if crumb =~# '\v^'.a:group.'\s+'
      call add(extracted, crumb)
    endif
  endfor

  if a:active
    Expect len(extracted) == 2
  else
    Expect empty(extracted) to_be_true
  endif
endfunction


function! s:expect_mark_cache(mark_name, line_no, presence)
  let cache = hlmarks#mark#get_cache()
  if a:presence
    Expect get(cache, a:mark_name, 0) == a:line_no
  else
    Expect get(cache, a:mark_name, 0) == 0
  endif
endfunction


function! s:expect_sign_cache(sign_name, line_no, presence)
  let cache = hlmarks#sign#get_cache()
  let key_in_cache = has_key(cache, a:line_no)

  if a:presence
    Expect key_in_cache to_be_true
  else
    if !key_in_cache
      return
    endif
  endif

  let sign_names = []
  for spec in cache[a:line_no].marks
    call add(sign_names, spec[1])
  endfor

  if a:presence
    Expect index(sign_names, a:sign_name) >= 0
  else
    Expect index(sign_names, a:sign_name) < 0
  endif
endfunction



describe 'Hlmarks'
  
  context 'when vim has been booted but before invoking activation process'

    it 'should provide interfaces'
      Expect maparg('<Plug>(hlmarks-activate)', 'n')            =~# '\V:<C-U>call hlmarks#activate_plugin()<CR>'
      Expect maparg('<Plug>(hlmarks-inactivate)', 'n')          =~# '\V:<C-U>call hlmarks#inactivate_plugin()<CR>'
      Expect maparg('<Plug>(hlmarks-reload)', 'n')              =~# '\V:<C-U>call hlmarks#reload_plugin()<CR>'
      Expect maparg('<Plug>(hlmarks-refresh-signs)', 'n')       =~# '\V:<C-U>call hlmarks#refresh_signs()<CR>'
      Expect maparg('<Plug>(hlmarks-automark)', 'n')            =~# '\V:<C-U>call hlmarks#set_automark(1)<CR>'
      Expect maparg('<Plug>(hlmarks-automark-global)', 'n')     =~# '\V:<C-U>call hlmarks#set_automark(0)<CR>'
      Expect maparg('<Plug>(hlmarks-remove-marks-line)', 'n')   =~# '\V:<C-U>call hlmarks#remove_marks_on_line()<CR>'
      Expect maparg('<Plug>(hlmarks-remove-marks-buffer)', 'n') =~# '\V:<C-U>call hlmarks#remove_marks_on_buffer()<CR>'
    end

    it 'should be loaded'
      Expect exists('g:loaded_hlmarks') to_be_true
      Expect g:loaded_hlmarks == 1
    end

    it 'should not define any user command'
      call s:expect_usercmd([], g:hlmarks_command_prefix)
    end

    it 'should have inactive state'
      call s:script_val.save()
      let local = s:script_val.get('')

      Expect local.is_active() to_be_false

      call s:script_val.restore()
    end

  end


  context 'when plugin is activated'

    before
      call hlmarks#activate_plugin()
    end

    after
      call hlmarks#inactivate_plugin()
      delm!
    end

    it 'should have active state'
      call s:script_val.save()
      let local = s:script_val.get('')

      Expect local.is_active() to_be_true

      call s:script_val.restore()
    end

    it 'should preserve some global variables'
      let repo = s:script_val.get('preserved')
      let target = keys(repo)

      for name in target
        Expect repo[name] == g:{name}
      endfor
    end

    it 'should define signs'
      call s:expect_sign_defs(1)
    end

    it 'should define keymaps'
      " Default prefix is 'Leader', it's presented as '\' in command result.
      call s:expect_keymap(1, '\', g:hlmarks_alias_native_mark_cmd)
    end

    it 'should define commands'
      call s:expect_usercmd(['Off', 'Reload'], g:hlmarks_command_prefix)
    end

    it 'should define autocmd'
      call s:expect_autocmd(1, g:hlmarks_autocmd_group)
    end

    it 'should accept to command for mark/sign'
      call hlmarks#set_mark('a', 1)

      call Expect_Mark(['a'], 1)
      call Expect_Sign(['HighlightMarks_a'], 1, 1)
    end

  end


  context 'when plugin is inactivated'

    before
      call hlmarks#activate_plugin()
      call hlmarks#set_mark('a', 1)
      call hlmarks#inactivate_plugin()
    end

    after
      delm!
    end

    it 'should have inactive state'
      call s:script_val.save()
      let local = s:script_val.get('')

      Expect local.is_active() to_be_false

      call s:script_val.restore()
    end

    it 'should remove autocmd'
      call s:expect_autocmd(0, g:hlmarks_autocmd_group)
    end

    it 'should define activate command only'
      call s:expect_usercmd(['On'], g:hlmarks_command_prefix)
    end

    it 'should remove keymap definition'
      " Default prefix is 'Leader', it's presented as '\' in command result.
      call s:expect_keymap(0, '\', g:hlmarks_alias_native_mark_cmd)
    end

    it 'should remove sign definition'
      call s:expect_sign_defs(0)
    end

    it 'should remove cache/signs'
      Expect hlmarks#sign#get_cache() == {}
      Expect hlmarks#mark#get_cache() == {}

      call Expect_Sign(['HighlightMarks_a'], 1, 0)
    end

  end


  context 'when plugin is reloaded'

    before
      call Save_Global()
      call s:script_val.save()
    end

    after
      call Restore_Global()
      call s:script_val.restore()
      delm!
    end

    it 'should reconfigure'
      call hlmarks#activate_plugin()
      call hlmarks#set_mark('a', 1)
      call hlmarks#set_mark('b', 1)

      call Expect_Mark(['a', 'b'], 1)
      call Expect_Sign(['HighlightMarks_a'], 1, 1)
      call Expect_Sign(['HighlightMarks_b'], 1, 1)

      let g:hlmarks_displaying_marks = substitute(g:hlmarks_displaying_marks, 'a', '', '')
      let g:hlmarks_prefix_key = '<Leader><Leader>'
      let g:hlmarks_alias_native_mark_cmd = '\sM'
      let g:hlmarks_command_prefix = 'HlMarksAlt'
      let g:hlmarks_autocmd_group = 'HlMarksAlt'

      call hlmarks#reload_plugin()

      call s:expect_sign_defs(1)

      call Expect_Mark(['a', 'b'], 1)
      call Expect_Sign(['HighlightMarks_a'], 1, 0)
      call Expect_Sign(['HighlightMarks_b'], 1, 1)

      let preserved = s:script_val.get('preserved')

      " Default prefix is 'Leader', it's presented as '\' in command result.
      call s:expect_keymap(1, '\', preserved['hlmarks_alias_native_mark_cmd'])
      call s:expect_autocmd(1, preserved['hlmarks_autocmd_group'])
      call s:expect_usercmd(['Off', 'Reload'], preserved['hlmarks_command_prefix'])

      call hlmarks#inactivate_plugin()
    end

  end

end


describe 'Display Utility'

  context 'refresh_signs()'

    before
      call Save_Global()
    end

    after
      call Restore_Global()
      delm!
    end

    it 'should refresh signs'
      let g:hlmarks_displaying_marks = g:hlmarks_displaying_marks . '.^'

      call hlmarks#activate_plugin()

      " " Create mark .^ (As below expresion, double quote is required for backslash and output escape.
      execute "normal Inew text \<Esc>"

      call Expect_Mark(['.', '^'], 1)
      call Expect_Sign(['HighlightMarks_.'], 1, 0)
      call Expect_Sign(['HighlightMarks_^'], 1, 0)

      call hlmarks#refresh_signs()

      call Expect_Sign(['HighlightMarks_.'], 1, 1)
      call Expect_Sign(['HighlightMarks_^'], 1, 1)

      call hlmarks#inactivate_plugin()
    end

    it 'should refresh signs when plugin is activated'
      normal ma
      normal mb

      call Expect_Mark(['a', 'b'], 1)
      call Expect_Sign(['HighlightMarks_a'], 1, 0)
      call Expect_Sign(['HighlightMarks_b'], 1, 0)

      call hlmarks#activate_plugin()

      call Expect_Mark(['a', 'b'], 1)
      call Expect_Sign(['HighlightMarks_a'], 1, 1)
      call Expect_Sign(['HighlightMarks_b'], 1, 1)

      call hlmarks#inactivate_plugin()
    end

  end

end


describe 'Deletion Utility'

  before
    new

    call hlmarks#activate_plugin()

    put = ['', '', '', '', '']

    call hlmarks#set_mark('a', 1)
    call hlmarks#set_mark('b', 1)
    call hlmarks#set_mark('c', 2)
  end

  after
    call hlmarks#inactivate_plugin()

    quit!
  end

  context 'remove_marks_on_buffer()'

    it 'should remove all marks and signs in current buffer'
      call Expect_Mark(['a', 'b', 'c'], 1)
      call Expect_Sign(['HighlightMarks_a'], 1, 1)
      call Expect_Sign(['HighlightMarks_b'], 1, 1)
      call Expect_Sign(['HighlightMarks_c'], 2, 1)

      call hlmarks#remove_marks_on_buffer()

      call Expect_Mark(['a', 'b', 'c'], 0)
      call Expect_Sign(['HighlightMarks_a'], 1, 0)
      call Expect_Sign(['HighlightMarks_b'], 1, 0)
      call Expect_Sign(['HighlightMarks_c'], 2, 0)
    end

  end

  context 'remove_marks_on_line()'

    it 'should remove all marks and signs on designated line'
      call Expect_Mark(['a', 'b', 'c'], 1)
      call Expect_Sign(['HighlightMarks_a'], 1, 1)
      call Expect_Sign(['HighlightMarks_b'], 1, 1)
      call Expect_Sign(['HighlightMarks_c'], 2, 1)

      call cursor(1, 1)
      call hlmarks#remove_marks_on_line()

      call Expect_Mark(['a', 'b'], 0)
      call Expect_Mark(['c'], 1)
      call Expect_Sign(['HighlightMarks_a'], 1, 0)
      call Expect_Sign(['HighlightMarks_b'], 1, 0)
      call Expect_Sign(['HighlightMarks_c'], 2, 1)
    end

  end

end


describe 'Private helper'

  before
    call s:script_val.save()
  end

  after
    call s:script_val.restore()
  end

  context 's:plugin.activate()'

    it 'should activate plugin state'
      call s:script_val.set({'activated': 999})
      let local = s:script_val.get('')

      call local.activate()
      let state = s:script_val.get('activated')

      Expect state == 1
    end

    it 'should inactivate plugin state'
      call s:script_val.set({'activated': 999})
      let local = s:script_val.get('')

      call local.inactivate()
      let state = s:script_val.get('activated')

      Expect state == 0
    end

  end

  context 's:plugin.is_active()'

    it 'should be tested in test for activate()/inactivate() functions'
      Expect 1 to_be_true
    end

  end

  context 's:preserve_definition_keyword()'

    it 'should be tested in test for activate() functions'
      Expect 1 to_be_true
    end

  end

  context 's:sweep_out()'

    it 'should remove cache/signs in all buffers and sign definition'
      call hlmarks#activate_plugin()

      " XXX: STOP AUTOCMD!(because, mark cache is set again when buffer enter)
      call Call('s:toggle_autocmd', 0)

      Expect hlmarks#sign#get_cache() == {}
      Expect hlmarks#mark#get_cache() == {}

      call hlmarks#set_mark('a', 1)

      call Expect_Mark(['a'], 1)
      call Expect_Sign(['HighlightMarks_a'], 1, 1)

      Expect hlmarks#sign#get_cache() != {}
      Expect hlmarks#mark#get_cache() != {}

      new

      Expect hlmarks#sign#get_cache() == {}
      Expect hlmarks#mark#get_cache() == {}

      call hlmarks#set_mark('b', 1)

      call Expect_Mark(['b'], 1)
      call Expect_Sign(['HighlightMarks_b'], 1, 1)

      Expect hlmarks#sign#get_cache() != {}
      Expect hlmarks#mark#get_cache() != {}

      call Call('s:sweep_out')

      call Expect_Mark(['b'], 1)
      call Expect_Sign(['HighlightMarks_b'], 1, 0)

      Expect hlmarks#sign#get_cache() == {}
      Expect hlmarks#mark#get_cache() == {}

      delm!
      quit!

      call Expect_Mark(['a'], 1)
      call Expect_Sign(['HighlightMarks_a'], 1, 0)

      Expect hlmarks#sign#get_cache() == {}
      Expect hlmarks#mark#get_cache() == {}

      call s:expect_sign_defs(0)

      call hlmarks#inactivate_plugin()
      delm!
    end

  end

  context 's:toggle_autocmd()'

    it 'should be tested in test for activate()/inactivate() functions'
      Expect 1 to_be_true
    end

  end

  context 's:toggle_key_mapping()'

    it 'should be tested in test for activate()/inactivate() functions'
      Expect 1 to_be_true
    end

  end

  context 's:toggle_usercmd()'

    it 'should be tested in test for activate()/inactivate() functions'
      Expect 1 to_be_true
    end

  end

end


describe 'set_mark()/set_automark()'

  before
    call hlmarks#activate_plugin()
    put = ['', '', '', '', '']
    call cursor(1, 1)
  end

  after
    call hlmarks#inactivate_plugin()
    delm!
    delm A
  end

  context '(omit line-no = to current line)'

    it 'should set new mark/sign'
      let lno = line('.')

      call hlmarks#set_mark('a')

      call Expect_Mark(['a'], 1)
      call Expect_Sign(['HighlightMarks_a'], lno, 1)
      call s:expect_mark_cache('a', lno, 1)
      call s:expect_sign_cache('HighlightMarks_a', lno, 1)
    end

    it 'should set auto-generated new mark/sign'
      let lno = line('.')

      call hlmarks#set_automark(1)

      call Expect_Mark(['a'], 1)
      call Expect_Sign(['HighlightMarks_a'], lno, 1)
      call s:expect_mark_cache('a', lno, 1)
      call s:expect_sign_cache('HighlightMarks_a', lno, 1)
    end

    it 'should set auto-generated global new mark/sign'
      let lno = line('.')

      call hlmarks#set_automark(0)

      call Expect_Mark(['A'], 1)
      call Expect_Sign(['HighlightMarks_A'], lno, 1)
      call s:expect_mark_cache('A', lno, 1)
      call s:expect_sign_cache('HighlightMarks_A', lno, 1)
    end

    it 'should move mark/sign from other line in same buffer'
      call hlmarks#set_mark('a')

      let lno = 3
      call cursor(lno, 1)

      call hlmarks#set_mark('a')

      call Expect_Mark(['a'], 1)
      call Expect_Sign(['HighlightMarks_a'], lno, 1)
      call s:expect_mark_cache('a', lno, 1)
      call s:expect_sign_cache('HighlightMarks_a', lno, 1)
    end

    it 'should move mark/sign from other line in other buffer'
      let first_lno = line('.')

      call hlmarks#set_mark('A')

      " To New buffer
      new
      put = ['', '', '', '', '']

      " Note: Expect_Mark() can NOT except global mark in other buffer, so set another line for checking.
      call cursor(3, 1)
      let lno = line('.')

      call hlmarks#set_mark('A')

      call Expect_Mark(['A'], 1)
      call Expect_Sign(['HighlightMarks_A'], lno, 1)
      call s:expect_mark_cache('A', lno, 1)
      call s:expect_sign_cache('HighlightMarks_A', lno, 1)

      " To First buffer = always 2 when new one is added
      execute '2wincmd w'

      " Note: Expect_Mark() can NOT except global mark in other buffer.
      Expect getpos("'A")[0] != bufnr('%')
      call Expect_Sign(['HighlightMarks_A'], first_lno, 0)
      call s:expect_mark_cache('A', first_lno, 0)
      call s:expect_sign_cache('HighlightMarks_A', first_lno, 0)

      " " Back to New buffer = always 1
      execute '1wincmd w'
      quit!
    end

    it 'should toggle mark/sign'
      let lno = line('.')

      call hlmarks#set_mark('a')
      call hlmarks#set_mark('a')

      call Expect_Mark(['a'], 0)
      call Expect_Sign(['HighlightMarks_a'], lno, 0)
      call s:expect_mark_cache('a', lno, 0)
      call s:expect_sign_cache('HighlightMarks_a', lno, 0)
    end

    it 'should delegate handling manually un-settable mark to native command'
      let lno = line('.')

      call hlmarks#set_mark('^')

      call Expect_Mark(['^'], 0)
      call Expect_Sign(['HighlightMarks_^'], lno, 0)
      call s:expect_mark_cache('^', lno, 0)
      call s:expect_sign_cache('HighlightMarks_^', lno, 0)
    end

  end


  context '(set line-no)'

    it 'should set new mark/sign'
      let [first_lno, lno] = [line('.'), 3]
      Expect first_lno != lno

      call hlmarks#set_mark('a', lno)

      call Expect_Mark(['a'], 1)
      call Expect_Sign(['HighlightMarks_a'], lno, 1)
      call s:expect_mark_cache('a', lno, 1)
      call s:expect_sign_cache('HighlightMarks_a', lno, 1)

      Expect line('.') == first_lno
    end

    it 'should set auto-generated new mark/sign'
      let [first_lno, lno] = [line('.'), 3]
      Expect first_lno != lno

      call hlmarks#set_automark(1, lno)

      call Expect_Mark(['a'], 1)
      call Expect_Sign(['HighlightMarks_a'], lno, 1)
      call s:expect_mark_cache('a', lno, 1)
      call s:expect_sign_cache('HighlightMarks_a', lno, 1)

      Expect line('.') == first_lno
    end

    it 'should set auto-generated global new mark/sign'
      let [first_lno, lno] = [line('.'), 3]
      Expect first_lno != lno

      call hlmarks#set_automark(0, lno)

      call Expect_Mark(['A'], 1)
      call Expect_Sign(['HighlightMarks_A'], lno, 1)
      call s:expect_mark_cache('A', lno, 1)
      call s:expect_sign_cache('HighlightMarks_A', lno, 1)

      Expect line('.') == first_lno
    end

    it 'should move mark/sign from other line in same buffer'
      let [first_lno, lno] = [line('.'), 3]
      Expect first_lno != lno

      call hlmarks#set_mark('a', first_lno)
      call hlmarks#set_mark('a', lno)

      call Expect_Mark(['a'], 1)
      call Expect_Sign(['HighlightMarks_a'], lno, 1)
      call s:expect_mark_cache('a', lno, 1)
      call s:expect_sign_cache('HighlightMarks_a', lno, 1)

      Expect line('.') == first_lno
    end

    it 'should move mark/sign from other line in other buffer'
      let [first_lno, lno] = [line('.'), 3]
      Expect first_lno != lno

      call hlmarks#set_mark('A', first_lno)

      " To New buffer
      new
      put = ['', '', '', '', '']
      call cursor(1, 1)

      call hlmarks#set_mark('A', lno)

      call Expect_Mark(['A'], 1)
      call Expect_Sign(['HighlightMarks_A'], lno, 1)
      call s:expect_mark_cache('A', lno, 1)
      call s:expect_sign_cache('HighlightMarks_A', lno, 1)

      " To First buffer = always 2 when new one is added
      execute '2wincmd w'

      " Note: Expect_Mark() can NOT except global mark in other buffer.
      Expect getpos("'A")[0] != bufnr('%')
      call Expect_Sign(['HighlightMarks_A'], first_lno, 0)
      call s:expect_mark_cache('A', first_lno, 0)
      call s:expect_sign_cache('HighlightMarks_A', first_lno, 0)

      " " Back to New buffer = always 1
      execute '1wincmd w'
      quit!
    end

    it 'should toggle mark/sign'
      let [first_lno, lno] = [line('.'), 3]
      Expect first_lno != lno

      call hlmarks#set_mark('a', lno)
      call hlmarks#set_mark('a', lno)

      call Expect_Mark(['a'], 0)
      call Expect_Sign(['HighlightMarks_a'], lno, 0)
      call s:expect_mark_cache('a', lno, 0)
      call s:expect_sign_cache('HighlightMarks_a', lno, 0)

      Expect line('.') == first_lno
    end

    it 'should delegate handling manually un-settable mark to native command'
      let [first_lno, lno] = [line('.'), 3]
      Expect first_lno != lno

      call hlmarks#set_mark('^', lno)

      call Expect_Mark(['^'], 0)
      call Expect_Sign(['HighlightMarks_^'], lno, 0)
      call s:expect_mark_cache('^', lno, 0)
      call s:expect_sign_cache('HighlightMarks_^', lno, 0)
    end

  end


  context '(set line-no = current line)'

    it 'should set new mark/sign'
      let [first_lno, lno] = [line('.'), line('.')]

      call hlmarks#set_mark('a', lno)

      call Expect_Mark(['a'], 1)
      call Expect_Sign(['HighlightMarks_a'], lno, 1)
      call s:expect_mark_cache('a', lno, 1)
      call s:expect_sign_cache('HighlightMarks_a', lno, 1)

      Expect line('.') == first_lno
    end

    it 'should set auto-generated new mark/sign'
      let [first_lno, lno] = [line('.'), line('.')]

      call hlmarks#set_automark(1, lno)

      call Expect_Mark(['a'], 1)
      call Expect_Sign(['HighlightMarks_a'], lno, 1)
      call s:expect_mark_cache('a', lno, 1)
      call s:expect_sign_cache('HighlightMarks_a', lno, 1)

      Expect line('.') == first_lno
    end

    it 'should set auto-generated global new mark/sign'
      let [first_lno, lno] = [line('.'), line('.')]

      call hlmarks#set_automark(0, lno)

      call Expect_Mark(['A'], 1)
      call Expect_Sign(['HighlightMarks_A'], lno, 1)
      call s:expect_mark_cache('A', lno, 1)
      call s:expect_sign_cache('HighlightMarks_A', lno, 1)

      Expect line('.') == first_lno
    end

    it 'should move mark/sign from other line in same buffer (Same as toggle)'
      let [first_lno, lno] = [line('.'), line('.')]

      call hlmarks#set_mark('a', first_lno)
      call hlmarks#set_mark('a', lno)

      call Expect_Mark(['a'], 0)
      call Expect_Sign(['HighlightMarks_a'], lno, 0)
      call s:expect_mark_cache('a', lno, 0)
      call s:expect_sign_cache('HighlightMarks_a', lno, 0)

      Expect line('.') == first_lno
    end

    it 'should move mark/sign from other line in other buffer'
      let [first_lno, lno] = [line('.'), line('.')]

      call hlmarks#set_mark('A', first_lno)

      " To New buffer
      new
      put = ['', '', '', '', '']
      call cursor(1, 1)

      call hlmarks#set_mark('A', lno)

      call Expect_Mark(['A'], 1)
      call Expect_Sign(['HighlightMarks_A'], lno, 1)
      call s:expect_mark_cache('A', lno, 1)
      call s:expect_sign_cache('HighlightMarks_A', lno, 1)

      " To First buffer = always 2 when new one is added
      execute '2wincmd w'

      " Note: Expect_Mark() can NOT except global mark in other buffer.
      Expect getpos("'A")[0] != bufnr('%')
      call Expect_Sign(['HighlightMarks_A'], first_lno, 0)
      call s:expect_mark_cache('A', first_lno, 0)
      call s:expect_sign_cache('HighlightMarks_A', first_lno, 0)

      " " Back to New buffer = always 1
      execute '1wincmd w'
      quit!
    end

    it 'should toggle mark/sign'
      let [first_lno, lno] = [line('.'), line('.')]

      call hlmarks#set_mark('a', lno)
      call hlmarks#set_mark('a', lno)

      call Expect_Mark(['a'], 0)
      call Expect_Sign(['HighlightMarks_a'], lno, 0)
      call s:expect_mark_cache('a', lno, 0)
      call s:expect_sign_cache('HighlightMarks_a', lno, 0)

      Expect line('.') == first_lno
    end

    it 'should delegate handling manually un-settable mark to native command'
      let [first_lno, lno] = [line('.'), line('.')]

      call hlmarks#set_mark('^', lno)

      call Expect_Mark(['^'], 0)
      call Expect_Sign(['HighlightMarks_^'], lno, 0)
      call s:expect_mark_cache('^', lno, 0)
      call s:expect_sign_cache('HighlightMarks_^', lno, 0)
    end

  end

end

