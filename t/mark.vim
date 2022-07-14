execute 'source ' . expand('%:p:h') . '/t/_common/test_helpers.vim'
execute 'source ' . expand('%:p:h') . '/t/_common/local_helpers.vim'

runtime! plugin/hlmarks.vim

call vspec#hint({'scope': 'hlmarks#mark#scope()', 'sid': 'hlmarks#mark#sid()'})

let s:script_val = Create_Script_Val_Handler('s:mark')



function! s:purge_mark()
  let marks = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789^.<>[]\"'
  execute 'delmarks '.marks
endfunction


function! s:win_id()
  " Available on Vim>=8.0.
  return win_getid()
endfunction


function! s:activate_win(win_id)
  " Available on Vim>=8.0.
  return win_gotoid(a:win_id)
endfunction


function! s:add_buffer()
  new
  return s:win_id()
endfunction


" Generate ^,. marks. (See README about the mark detail)
function! s:generate_automated_mark()
  let line_no = 1
  call cursor(line_no, 1)
  " This invocation sets ^,. on line_no.
  execute "normal Inew text \<Esc>"
  " This invocation sets . on next line(line_no+1).
  " Must set another line of ^ for deletion test.
  put =['']

  return {'^': line_no, '.': (line_no + 1)}
endfunction


" Use for a-Z marks. (See README about the mark detail)
function! s:set_generic_mark(...)
  let marks = type(a:1) == v:t_list ? a:1 : split(a:1, '\zs')
  let on_same_line = a:0 == 2 ? a:2 : 0
  let specs = {}
  let line_no = 1

  for name in marks
    put =['']               " Create empty line under the current one.
    call cursor(line_no, 1) " Bring the cursor back to the current line.
    execute 'normal m'.name
    let specs[name] = line_no
    if !on_same_line
      let line_no += 1
    endif
  endfor

  return specs
endfunction


" Use for <,> marks. (See README about the mark detail)
function! s:set_angle_brackets_mark(right)
  let marks = a:right ? ['<', '>'] : ['<']
  let specs = {}
  let line_no = 1

  for name in marks
    put =['']
    call cursor(line_no, 1)
    execute 'normal m'.name
    let specs[name] = line_no
    let line_no += 1
  endfor

  return specs
endfunction


" Use for quote,[,] marks. (See README about the mark detail)
function! s:set_one_mark(mark)
  let line_no = 1
  call cursor(line_no, 1)
  execute 'normal m'.a:mark

  return line_no
endfunction


" Use for invisible (,),{,} marks.
function! s:set_invisible_mark()
  " Move new buffer because a paragraph range(for {,} marks) cannot be assumed by other tests.
  call s:activate_win(s:add_buffer())
  call cursor(1, 1) " Move to line 1.
  put =['']         " Add line, the cursor is on line 2 but sentence-rage is line 1-2.

  return {'(': 1, ')': 2, '{': 1, '}': 2} " Thus, spec becomes as here.
endfunction


function! s:expect_remove(current_win_id, current_buffer_marks, other_win_id, other_buffer_marks)
  call s:activate_win(a:current_win_id)
  call hlmarks#mark#remove(a:current_buffer_marks)

  call Expect_Mark(a:current_buffer_marks, 0)

  call s:activate_win(a:other_win_id)

  call Expect_Mark(a:other_buffer_marks, 1)
endfunction


function! s:expect_remove_All(current_win_id, current_buffer_marks, other_win_id, other_buffer_marks)
  call s:activate_win(a:current_win_id)
  call hlmarks#mark#remove_all()

  call Expect_Mark(a:current_buffer_marks, 0)

  call s:activate_win(a:other_win_id)

  call Expect_Mark(a:other_buffer_marks, 1)
endfunction


function! s:expect_remove_On_Line(current_win_id, current_mark_spec, other_win_id, other_buffer_marks)
  let mark_spec = type(a:current_mark_spec) == v:t_dict ? items(a:current_mark_spec) : a:current_mark_spec

  call s:activate_win(a:current_win_id)

  for [name, line_no] in mark_spec
    let result = hlmarks#mark#remove_on_line(line_no)

    if result == []
      call vspec#debug(name.'='.line_no.':'.(string(getpos("'".name))))
    endif

    Expect result != []

    " There's possibility that result has two or more marks (e.g. automated-updating marks)
    " even if set each marks at different line, thus can't compare == operator.
    Expect index(result, name) >= 0
    call Expect_Mark(name, 0)
  endfor

  call s:activate_win(a:other_win_id)

  call Expect_Mark(a:other_buffer_marks, 1)
endfunction


function! s:expect_bundle(mark_spec)
  let bundle = Call(Get_Val('func'), join(keys(a:mark_spec), ''))

  Expect bundle !~? 'error'

  for [name, line_no] in items(a:mark_spec)
    let escaped = escape(name, '^.<>[]{}()')

    if index(['(', ')', '{', '}'], name) == -1
      Expect bundle =~# '\v'.escaped.'\s+'.line_no.'\D+'
    else
      Expect bundle =~# '\v'.escaped.'\s+'.line_no.'.{-1,}\(invisible\)'
    endif
  endfor
endfunction


function! s:expect_bundle_Extract(mark_spec)
  let bundle = Call(Get_Val('bundle_func'), join(keys(a:mark_spec), ''))
  let result = Call(Get_Val('func'), bundle, 1)

  Expect len(result) == len(a:mark_spec)

  for [name, line_no] in items(result)
    Expect line_no == a:mark_spec[name]
  endfor
endfunction



describe 'specs_for_sign()'

  before
    call Save_Global()
  end

  after
    call Restore_Global()
    call s:purge_mark()
  end

  it 'should return local/global mark specs defined in global option only in current buffer'
    let g:hlmarks_displaying_marks = 'aA'
    let defined_marks = split(g:hlmarks_displaying_marks, '\zs')
    let mark_spec = s:set_generic_mark(defined_marks)
    let result = hlmarks#mark#specs_for_sign()

    Expect len(mark_spec) == len(defined_marks)
    Expect len(result) == len(mark_spec)

    for [name, line_no] in items(result)
      Expect index(defined_marks, name) >= 0
      Expect has_key(mark_spec, name) to_be_true
      Expect line_no == mark_spec[name]
    endfor
  end

  it 'should return empty dict if no mark is placed'
    Expect hlmarks#mark#specs_for_sign() == {}
  end

end


describe 'generate_name()'

  before
    call s:script_val.save()
  end

  after
    call s:script_val.restore()
    call s:purge_mark()
  end

  context '(1st arg = 1 = name for local marks)'

    it 'should return next character that is not used yet in a-z'
      call s:set_generic_mark('a')
      call s:script_val.set({'automarkables': 'abAB'})

      Expect hlmarks#mark#generate_name(1) == 'b'
    end

    it 'should not return global marks(A-Z)'
      call s:set_generic_mark('b')
      call s:script_val.set({'automarkables': 'abAB'})

      Expect hlmarks#mark#generate_name(1) == 'a'
    end

    it 'should return empty string if all marks are used'
      call s:set_generic_mark('ab')
      call s:script_val.set({'automarkables': 'abAB'})

      Expect hlmarks#mark#generate_name(1) == ''
    end

  end

  context '(1st arg = 0 = name for global marks, only current buffer)'

    it 'should return next character that is not used yet in A-Z'
      call s:set_generic_mark('A')
      call s:script_val.set({'automarkables': 'abAB'})

      Expect hlmarks#mark#generate_name(0) == 'B'
    end

    it 'should not return local marks(a-z)'
      call s:set_generic_mark('B')
      call s:script_val.set({'automarkables': 'abAB'})

      Expect hlmarks#mark#generate_name(0) == 'A'
    end

    it 'should return empty string if all marks are used'
      call s:set_generic_mark('AB')
      call s:script_val.set({'automarkables': 'abAB'})

      Expect hlmarks#mark#generate_name(0) == ''
    end

  end

  context '(1st arg = 0 = name for global marks, both current/other buffer)'

    it 'should return next character that is not used yet in A-Z'
      call s:set_generic_mark('A')
      call s:activate_win(s:add_buffer())
      call s:set_generic_mark('B')
      call s:script_val.set({'automarkables': 'abABC'})

      Expect hlmarks#mark#generate_name(0) == 'C'
    end

    it 'should not return local marks(a-z)'
      call s:set_generic_mark('B')
      call s:activate_win(s:add_buffer())
      call s:set_generic_mark('C')
      call s:script_val.set({'automarkables': 'abABC'})

      Expect hlmarks#mark#generate_name(0) == 'A'
    end

    it 'should return empty string if all marks are used'
      call s:set_generic_mark('AB')
      call s:activate_win(s:add_buffer())
      call s:set_generic_mark('C')
      call s:script_val.set({'automarkables': 'abABC'})

      Expect hlmarks#mark#generate_name(0) == ''
    end

  end

end


describe 'generate_state()'

  after
    call s:purge_mark()
  end

  it 'should generate current mark state'
    let mark_spec = s:set_generic_mark('ab')
    let state = hlmarks#mark#generate_state()

    Expect len(state) == len(mark_spec)

    for [name, line_no] in items(state)
      Expect has_key(mark_spec, name) to_be_true
      Expect mark_spec[name] == line_no
    endfor
  end

end


describe 'get_cache()'

  after
    call s:purge_mark()
  end

  it 'should return empty hash if cache is empty'
    let cache = hlmarks#mark#get_cache()

    Expect cache == {}
  end

  it 'should return cache that is set by set_cache()'
    let mark_spec = s:set_generic_mark('ab')
    call hlmarks#mark#set_cache()
    let cache = hlmarks#mark#get_cache()

    Expect len(cache) == len(mark_spec)

    for [name, line_no] in items(cache)
      Expect has_key(mark_spec, name) to_be_true
      Expect mark_spec[name] == line_no
    endfor
  end

end


describe 'should_handle()'

  before
    call s:script_val.save()
    call s:script_val.set({'togglables': 'abc'})
  end

  after
    call s:script_val.restore()
  end

  it 'should return true passed mark has correct length and is in predefined list'
    Expect hlmarks#mark#should_handle('a') to_be_true
  end

  it 'should return false passed mark has 2 or more length or is not in list'
    Expect hlmarks#mark#should_handle('d') to_be_false
    Expect hlmarks#mark#should_handle('aa') to_be_false
  end

end


describe 'pos()'

  after
    call s:purge_mark()
  end

  it 'should return line/buffer number for a-Z marks'
    let mark_spec = s:set_generic_mark('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ')
    let buffer_no = bufnr('%')

    for [name, line_no] in items(mark_spec)
      Expect hlmarks#mark#pos(name) == [buffer_no, line_no]
    endfor
  end

  it 'should return line/buffer number for <,> marks'
    let mark_spec = s:set_angle_brackets_mark(1)
    let buffer_no = bufnr('%')

    for [name, line_no] in items(mark_spec)
      Expect hlmarks#mark#pos(name) == [buffer_no, line_no]
    endfor
  end

  it 'should return line/buffer number for ^,. marks'
    let mark_spec = s:generate_automated_mark()
    let buffer_no = bufnr('%')

    for [name, line_no] in items(mark_spec)
      Expect hlmarks#mark#pos(name) == [buffer_no, line_no]
    endfor
  end

  it 'should return line/buffer number for single-quote mark'
    let line_no = s:set_one_mark("'")
    let buffer_no = bufnr('%')

    Expect hlmarks#mark#pos("'") == [buffer_no, line_no]
  end

  it 'should return line/buffer number for " mark'
    let line_no = s:set_one_mark('"')
    let buffer_no = bufnr('%')

    Expect hlmarks#mark#pos('"') == [buffer_no, line_no]
  end

  it 'should return line/buffer number for [,] marks'
    " Must set separately because it will change the other's line number.
    let marks = ['[', ']']
    let buffer_no = bufnr('%')

    for name in marks
      let line_no = s:set_one_mark(name)

      Expect hlmarks#mark#pos(name) == [buffer_no, line_no]
    endfor
  end

  it 'should return line/buffer number for invisible (,),{,} marks'
    let mark_spec = s:set_invisible_mark()
    let buffer_no = bufnr('%')

    for [name, line_no] in items(mark_spec)
      Expect hlmarks#mark#pos(name) == [buffer_no, line_no]
    endfor
  end

end


describe 'remove()'

  after
    call s:purge_mark()
  end

  it 'should remove a-Z marks'
    let current_buffer_marks = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLM'
    let other_buffer_marks = 'abcdefghijklmnopqrstuvwxyzNOPQRSTUVWXYZ'

    let current_win_id = s:win_id()
    call s:set_generic_mark(current_buffer_marks)

    let other_win_id = s:add_buffer()
    call s:activate_win(other_win_id)
    call s:set_generic_mark(other_buffer_marks)

    call s:expect_remove(current_win_id, current_buffer_marks, other_win_id, other_buffer_marks)
  end

  it 'should remove <,> marks'
    let marks = '<>'

    let current_win_id = s:win_id()
    call s:set_angle_brackets_mark(1)

    let other_win_id = s:add_buffer()
    call s:activate_win(other_win_id)
    call s:set_angle_brackets_mark(1)

    call s:expect_remove(current_win_id, marks, other_win_id, marks)
  end

  it 'should remove ^,. marks'
    let marks = '^.'

    let current_win_id = s:win_id()
    call s:generate_automated_mark()

    let other_win_id = s:add_buffer()
    call s:activate_win(other_win_id)
    call s:generate_automated_mark()

    call s:expect_remove(current_win_id, marks, other_win_id, marks)
  end

  it 'should try to remove single-quote mark that is unable to remove without error'
    let mark = "'"
    call s:set_one_mark(mark)

    call hlmarks#mark#remove(mark)
  end

  it 'should remove " mark'
    let mark = '"'

    let current_win_id = s:win_id()
    call s:set_one_mark(mark)

    let other_win_id = s:add_buffer()
    call s:activate_win(other_win_id)
    call s:set_one_mark(mark)

    call s:expect_remove(current_win_id, mark, other_win_id, mark)
  end

  it 'should remove [,] marks'
    " No need to set separately in this case because line number is not used for test,
    " so can use set_generic_mark().
    let marks = '[]'

    let current_win_id = s:win_id()
    call s:set_generic_mark(marks)

    let other_win_id = s:add_buffer()
    call s:activate_win(other_win_id)
    call s:set_generic_mark(marks)

    call s:expect_remove(current_win_id, marks, other_win_id, marks)
  end

  it 'should try to remove invisible (,),{,} marks that are unable to remove without error'
    let marks = '(){}'
    call s:set_invisible_mark()

    call hlmarks#mark#remove(marks)
  end

end


describe 'remove_all()'

  after
    call s:purge_mark()
  end

  it 'should remove a-Z marks in current buffer only'
    let current_buffer_marks = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLM'
    let other_buffer_marks = 'abcdefghijklmnopqrstuvwxyzNOPQRSTUVWXYZ'

    let current_win_id = s:win_id()
    call s:set_generic_mark(current_buffer_marks)

    let other_win_id = s:add_buffer()
    call s:activate_win(other_win_id)
    call s:set_generic_mark(other_buffer_marks)

    call s:expect_remove_All(current_win_id, current_buffer_marks, other_win_id, other_buffer_marks)
  end

  it 'should remove <,> marks in current buffer only'
    let marks = '<>'

    let current_win_id = s:win_id()
    call s:set_angle_brackets_mark(1)

    let other_win_id = s:add_buffer()
    call s:activate_win(other_win_id)
    call s:set_angle_brackets_mark(1)

    call s:expect_remove_All(current_win_id, marks, other_win_id, marks)
  end

  it 'should remove ^,. marks in current buffer only'
    let marks = '^.'

    let current_win_id = s:win_id()
    call s:generate_automated_mark()

    let other_win_id = s:add_buffer()
    call s:activate_win(other_win_id)
    call s:generate_automated_mark()

    call s:expect_remove_All(current_win_id, marks, other_win_id, marks)
  end

  it 'should try to remove single-quote mark that is unable to remove without error'
    let mark = "'"
    call s:set_one_mark(mark)

    call hlmarks#mark#remove_all()
  end

  it 'should remove " mark in current buffer only'
    let mark = '"'

    let current_win_id = s:win_id()
    call s:set_one_mark(mark)

    let other_win_id = s:add_buffer()
    call s:activate_win(other_win_id)
    call s:set_one_mark(mark)

    call s:expect_remove_All(current_win_id, mark, other_win_id, mark)
  end

  it 'should remove [,] marks in current buffer only'
    " No need to set separately in this case because line number is not used for test,
    " so can use set_generic_mark().
    let marks = '[]'

    let current_win_id = s:win_id()
    call s:set_generic_mark(marks)

    let other_win_id = s:add_buffer()
    call s:activate_win(other_win_id)
    call s:set_generic_mark(marks)

    call s:expect_remove_All(current_win_id, marks, other_win_id, marks)
  end

  it 'should try to remove invisible (,),{,} marks that are unable to remove without error'
    call s:set_invisible_mark()

    call hlmarks#mark#remove_all()
  end

end


describe 'remove_on_line()'

  after
    call s:purge_mark()
  end

  it 'should remove a-Z marks in current buffer only'
    let current_buffer_marks = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLM'
    let other_buffer_marks = 'abcdefghijklmnopqrstuvwxyzNOPQRSTUVWXYZ'

    let current_win_id = s:win_id()
    let mark_spec = s:set_generic_mark(current_buffer_marks)

    let other_win_id = s:add_buffer()
    call s:activate_win(other_win_id)
    call s:set_generic_mark(other_buffer_marks)

    call s:expect_remove_On_Line(current_win_id, mark_spec, other_win_id, other_buffer_marks)
  end

  it 'should remove <,> marks in current buffer only'
    let marks = '<>'

    let current_win_id = s:win_id()
    let mark_spec = s:set_angle_brackets_mark(1)

    let other_win_id = s:add_buffer()
    call s:activate_win(other_win_id)
    call s:set_angle_brackets_mark(1)

    " Must remove right angle-brackets at first because it will change to left one if remove left one at first. 
    call s:expect_remove_On_Line(current_win_id, [['>', mark_spec['>']], ['<', mark_spec['<']]], other_win_id, marks)
  end

  it 'should remove ^,. marks in current buffer only'
    let marks = '^.'

    let current_win_id = s:win_id()
    let mark_spec = s:generate_automated_mark()

    let other_win_id = s:add_buffer()
    call s:activate_win(other_win_id)
    call s:generate_automated_mark()

    call s:expect_remove_On_Line(current_win_id, mark_spec, other_win_id, marks)
  end

  it 'should try to remove single-quote mark that is unable to remove without error'
    let mark = "'"
    let line_no = s:set_one_mark(mark)

    call hlmarks#mark#remove_on_line(line_no)
  end

  it 'should remove " mark in current buffer only'
    let mark = '"'

    let current_win_id = s:win_id()
    let line_no = s:set_one_mark(mark)

    let other_win_id = s:add_buffer()
    call s:activate_win(other_win_id)
    call s:set_one_mark(mark)

    call s:expect_remove_On_Line(current_win_id, [[mark, line_no]], other_win_id, mark)
  end

  it 'should remove [,] marks in current buffer only'
    " Must set separately because it will change the other's line number.
    let marks = ['[', ']']
    let current_win_id = s:win_id()
    let other_win_id = s:add_buffer()

    for name in marks
      call s:activate_win(current_win_id)
      let line_no = s:set_one_mark(name)

      call s:activate_win(other_win_id)
      call s:set_one_mark(name)

      call s:expect_remove_On_Line(current_win_id, [[name, line_no]], other_win_id, name)
    endfor
  end

  it 'should try to remove invisible (,),{,} marks that are unable to remove without error'
    let mark_spec = s:set_invisible_mark()

    for line_no in values(mark_spec)
      call hlmarks#mark#remove_on_line(line_no)
    endfor
  end

  it 'should remove all marks on same line'
    let marks = 'ab'
    let mark_spec = s:set_generic_mark(marks, 1)
    let line_no = values(mark_spec)[0]

    let result = hlmarks#mark#remove_on_line(line_no)

    for name in split(marks, '\zs')
      Expect index(result, name) >= 0
    endfor

    call Expect_Mark(marks, 0)
  end

end


describe 'set()'

  after
    call s:purge_mark()
  end

  it 'should set mark that can be placed manually'
    let marks = split('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ''"<>[]', '\zs')

    " Must only use native function in here so drop hook.
    silent! execute printf('noremap <script><unique> %s m', g:hlmarks_alias_native_mark_cmd)

    for name in marks
      call hlmarks#mark#set(name)
    endfor

    call Expect_Mark(marks, 1)

    " Revert hook.
    silent! execute printf('unmap %s', g:hlmarks_alias_native_mark_cmd)
  end

end


describe 's:bundle()'

  before
    call Register_Val({
      \ 'func': 's:bundle',
      \ })
  end

  after
    call Purge_Val()
    call s:purge_mark()
  end

  it 'should return single chunk contains designated a-Z marks information'
    let current_buffer_marks = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLM'
    let other_buffer_marks = 'NOPQRSTUVWXYZ'

    let current_win_id = s:win_id()
    let mark_spec = s:set_generic_mark(current_buffer_marks)

    call s:activate_win(s:add_buffer())
    call extend(mark_spec, s:set_generic_mark(other_buffer_marks))
    call s:activate_win(current_win_id)

    call s:expect_bundle(mark_spec)
  end

  it 'should return single chunk contains <,> marks information'
    let mark_spec = s:set_angle_brackets_mark(1)

    call s:expect_bundle(mark_spec)
  end

  it 'should return single chunk contains ^,. marks information'
    let mark_spec = s:generate_automated_mark()

    call s:expect_bundle(mark_spec)
  end

  it 'should return single chunk contains single-quote mark information'
    let mark_spec = {"'": s:set_one_mark("'")}

    call s:expect_bundle(mark_spec)
  end

  it 'should return single chunk contains " mark information'
    let mark_spec = {'"': s:set_one_mark('"')}

    call s:expect_bundle(mark_spec)
  end

  it 'should return single bundle contains [,] marks information'
    " Must set separately because it will change the other's line number.
    let marks = ['[', ']']

    for name in marks
      let mark_spec = {}
      let mark_spec[name] = s:set_one_mark(name)

      call s:expect_bundle(mark_spec)
    endfor
  end

  it 'should return single chunk contains invisible marks information that normally cannot get by command'
    let mark_spec = s:set_invisible_mark()

    call s:expect_bundle(mark_spec)
  end

  it 'should return single bundle only contains marks in current buffer'
    let current_win_id = s:win_id()

    call s:activate_win(s:add_buffer())
    let mark_spec = s:set_generic_mark('a')
    call s:activate_win(current_win_id)

    let bundle = Call(Get_Val('func'), 'a')

    Expect bundle !~# '\va\s+'.mark_spec['a'].'\D+'
  end

end


describe 's:extract()'

  before
    call Register_Val({
      \ 'func': 's:extract',
      \ 'bundle_func': 's:bundle',
      \ })
  end

  after
    call Purge_Val()
    call s:purge_mark()
  end

  it 'should extract a-Z marks information from bundle'
    let mark_spec = s:set_generic_mark('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ')

    call s:expect_bundle_Extract(mark_spec)
  end

  it 'should extract <,> marks information from bundle'
    let mark_spec = s:set_angle_brackets_mark(1)

    call s:expect_bundle_Extract(mark_spec)
  end

  it 'should extract ^,. marks information from bundle'
    let mark_spec = s:generate_automated_mark()

    call s:expect_bundle_Extract(mark_spec)
  end

  it 'should extract sigle-quote mark information from bundle'
    let mark_spec = {"'": s:set_one_mark("'")}

    call s:expect_bundle_Extract(mark_spec)
  end

  it 'should extract " mark information from bundle'
    let mark_spec = {'"': s:set_one_mark('"')}

    call s:expect_bundle_Extract(mark_spec)
  end

  it 'should extract [,] marks information from bundle'
    " Must set separately because it will change the other's line number.
    let marks = ['[', ']']

    for name in marks
      let mark_spec = {}
      let mark_spec[name] = s:set_one_mark(name)

      call s:expect_bundle_Extract(mark_spec)
    endfor
  end

  it 'should extract invisible marks information from bundle'
    let mark_spec = s:set_invisible_mark()

    call s:expect_bundle_Extract(mark_spec)
  end

  it 'should extract except global mark in other buffer'
    let current_win_id = s:win_id()

    call s:activate_win(s:add_buffer())
    let mark_spec = s:set_generic_mark('A')
    call s:activate_win(current_win_id)

    let bundle = Call(Get_Val('bundle_func'), 'A')
    let result = Call(Get_Val('func'), bundle, 0)

    Expect result == {}
  end

  it 'should return empty dict if has no mark'
    let bundle = Call(Get_Val('bundle_func'), 'aA')
    let result = Call(Get_Val('func'), bundle, 1)

    Expect result == {}
  end

end

