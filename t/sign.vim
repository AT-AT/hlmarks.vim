execute 'source ' . expand('%:p:h') . '/t/_common/test_helpers.vim'
execute 'source ' . expand('%:p:h') . '/t/_common/local_helpers.vim'

runtime! plugin/hlmarks.vim

call vspec#hint({'scope': 'hlmarks#sign#scope()', 'sid': 'hlmarks#sign#sid()'})



function! s:Reg(subject)
  return _Reg_('__t__', a:subject)
endfunction


function! s:StashGlobal(subject)
  let subject = a:subject != 0 ? 'hlmarks_' : 0
  call _Stash_(subject)
endfunction


function! s:Local(subject)
  return _HandleLocalDict_('s:sign', a:subject)
endfunction


function! s:sign_prefix()
  return '__test__'
endfunction


function! s:define_sign(define, ...)
  let signs = a:0 ? a:1 : ['a', 'b', 'c']
  let sign_names = []
  " Should define for single chars in displaying list.
  for name in signs
    let sign_name = s:sign_prefix().name
    execute 'sign '.(a:define ? '' : 'un').'define '.sign_name
    call add(sign_names, sign_name)
  endfor

  return sign_names
endfunction


function! s:place_sign(sign_names, ...)
  let start_id = a:0 ? a:1 : 1
  if type(a:sign_names) == type(1) && a:sign_names == 0
    sign unplace *
    return []
  endif

  let sign_ids = []
  let id = start_id
  for sign_name in a:sign_names
    execute printf('sign place %s line=%s name=%s buffer=%s', id, 1, sign_name, bufnr('%'))
    call add(sign_ids, id)
    let id += 1
  endfor

  return sign_ids
endfunction


function! s:extract_name_from_defs(sign_names)
  let prefix = s:sign_prefix()
  let names = []
  for sign_name in a:sign_names
    call add(names, substitute(sign_name, prefix, '', ''))
  endfor
  return names
endfunction


function! s:extract_name_from_specs(sign_units)
  let sign_names = []
  for unit in a:sign_units
    call add(sign_names, unit[1])
  endfor
  return sign_names
endfunction



describe 'define()/undefine()'

  it 'should define signs as fixed format and undefine those definitions'
    call s:Local(1)
    call s:Local({'prefix': 'SLF_'})
    let total_def_amount = strlen(g:hlmarks_displaying_marks)

    call hlmarks#sign#define()

    let bundle = _Grab_('sign list')
    let extracted = []
    for crumb in bundle
      if stridx(crumb, 'SLF_') >= 0
        call add(extracted, crumb)
      endif
    endfor

    Expect len(extracted) == total_def_amount

    for crumb in extracted
      Expect crumb =~ '\vSLF_. .+ linehl\=SLF_L_.{-1,} texthl\=SLF_G_.+'
    endfor

    call hlmarks#sign#undefine()

    let bundle = _Grab_('sign list')
    let extracted = []
    for crumb in bundle
      if stridx(crumb, 'SLF_') >= 0
        call add(extracted, crumb)
      endif
    endfor

    Expect len(extracted) == 0

    call s:Local(0)
  end

end


describe 'generate_state()'

  it 'should generate current sign spec'
    call s:Local(1)
    call s:Local({'prefix': s:sign_prefix()})
    let sign_names = s:define_sign(1)
    let sign_ids = s:place_sign(sign_names)

    let specs = hlmarks#sign#generate_state()
    let extracted = []
    for [line_no, spec] in items(specs)
      if line_no == 1
        call add(extracted, spec)
      endif
    endfor

    Expect len(extracted) == 1

    let extracted_names = s:extract_name_from_specs(extracted[0].marks)

    Expect extracted_names == sign_names
    Expect extracted[0].ids == sign_ids

    call s:place_sign(0)
    call s:define_sign(0)
    call s:Local(0)
  end

end


describe 'get_cache()'

  it 'should return empty hash if cache is empty'
    let cache = hlmarks#sign#get_cache()

    Expect cache == {}
  end

  it 'should return cache that is set by set_cache()'
    call s:Local(1)
    call s:Local({'prefix': s:sign_prefix()})
    let sign_names = s:define_sign(1)
    let sign_ids = s:place_sign(sign_names)

    call hlmarks#sign#set_cache()

    let cache = hlmarks#sign#get_cache()

    Expect len(cache) == 1
    Expect has_key(cache, '1') to_be_true

    let extracted_names = s:extract_name_from_specs(cache['1'].marks)

    Expect extracted_names == sign_names
    Expect cache['1'].ids == sign_ids

    call s:place_sign(0)
    call s:define_sign(0)
    call s:Local(0)
  end

end


describe 'place_on_mark()'

  before
    call s:StashGlobal(1)
    call s:Local(1)
    call s:Local({'prefix': s:sign_prefix()})

    let signs = s:define_sign(1)

    call s:Reg({
      \ 'signs': signs,
      \ 'names': s:extract_name_from_defs(signs),
      \})

    let g:hlmarks_displaying_marks = 'cba'
  end

  after
    call s:place_sign(0)
    call s:define_sign(0)
    call s:Reg(0)
    call s:Local(0)
    call s:StashGlobal(0)
  end

  it 'should place signs on designated line as name for designated mark (order=as-is)'
    let signs = s:Reg('signs')
    let names = s:Reg('names')

    let g:hlmarks_sort_stacked_signs = 0

    for name in names
      call hlmarks#sign#place_on_mark(1, name)
    endfor

    let ordered_signs = Expect_Sign(signs, 1, 1)

    Expect ordered_signs == signs
  end

  it 'should place signs on designated line as name for designated mark (ordered)'
    let signs = deepcopy(s:Reg('signs'), 1)
    let names = s:Reg('names')

    let g:hlmarks_sort_stacked_signs = 1

    for name in names
      call hlmarks#sign#place_on_mark(1, name)
    endfor

    let ordered_signs = Expect_Sign(signs, 1, 1)

    call reverse(signs)

    Expect ordered_signs == signs
  end

end


describe 'place_with_delta()'

  before
    call s:StashGlobal(1)
    call s:Local(1)
    call s:Local({'prefix': s:sign_prefix()})
    call s:Reg({
      \ 'signs': s:define_sign(1),
      \})

    let g:hlmarks_sort_stacked_signs = 1
    let g:hlmarks_displaying_marks = 'cba'
  end

  after
    call s:place_sign(0)
    call s:define_sign(0)
    call s:Reg(0)
    call s:Local(0)
    call s:StashGlobal(0)
  end

  it 'should place signs accroding to delta between two cache data'
    let signs = deepcopy(s:Reg('signs'), 1)

    call s:place_sign(signs[0:-2])
    call hlmarks#sign#set_cache()
    call s:place_sign([signs[-1]], 10)

    call hlmarks#sign#place_with_delta()

    let ordered_signs = Expect_Sign(signs, 1, 1)

    call reverse(signs)

    Expect ordered_signs == signs
  end

  it 'should place signs accroding to delta that calculated by args'
    let signs = deepcopy(s:Reg('signs'), 1)

    call s:place_sign(signs[0:-2])
    let before = hlmarks#sign#generate_state()
    call s:place_sign([signs[-1]], 10)
    let after = hlmarks#sign#generate_state()

    call hlmarks#sign#place_with_delta(before, after)

    let ordered_signs = Expect_Sign(signs, 1, 1)

    call reverse(signs)

    Expect ordered_signs == signs
  end

end


describe 'remove_all()'

  before
    call s:Local(1)
    call s:Local({'prefix': s:sign_prefix()})

    let signs = s:define_sign(1)

    call s:Reg({
      \ 'signs': signs,
      \})

    call s:place_sign(signs)
  end

  after
    call s:place_sign(0)
    call s:define_sign(0)
    call s:Reg(0)
    call s:Local(0)
  end

  it 'should remove all signs on mark in current buffer if no buffer number is designated'
    call hlmarks#sign#remove_all()

    call Expect_Sign(s:Reg('signs'), 1, 0)
  end

  it 'should remove all signs on mark in designated buffer'
    call hlmarks#sign#remove_all([bufnr('%')])

    call Expect_Sign(s:Reg('signs'), 1, 0)
  end

end


describe 'remove_on_mark()'

  before
    call s:Local(1)
    call s:Local({'prefix': s:sign_prefix()})

    let signs = s:define_sign(1)

    call s:Reg({
      \ 'signs': signs,
      \ 'names': s:extract_name_from_defs(signs),
      \})

    call s:place_sign(signs)
  end

  after
    call s:place_sign(0)
    call s:define_sign(0)
    call s:Reg(0)
    call s:Local(0)
  end

  it 'should remove sign named designated mark name in current buffer if no buffer number is designated'
    let signs = s:Reg('signs')
    let removed_sign = s:Reg('names')[0]

    call hlmarks#sign#remove_on_mark(removed_sign)

    call Expect_Sign([removed_sign], 1, 0)
    call Expect_Sign(signs[1:], 1, 1)
  end

  it 'should remove sign named designated mark name in designated buffer'
    let signs = s:Reg('signs')
    let removed_sign = s:Reg('names')[0]

    call hlmarks#sign#remove_on_mark(removed_sign, bufnr('%'))

    call Expect_Sign([removed_sign], 1, 0)
    call Expect_Sign(signs[1:], 1, 1)
  end

end


describe 'should_place()'

  before
    call s:StashGlobal(1)

    new
  end

  after
    quit!

    call s:StashGlobal(0)
  end

  it 'should return true if all buffer type/state are permitted'
    let g:hlmarks_ignore_buffer_type = ''

    set buftype=help
    Expect hlmarks#sign#should_place() to_be_true

    set buftype=quickfix
    Expect hlmarks#sign#should_place() to_be_true

    set pvw
    Expect hlmarks#sign#should_place() to_be_true

    set ro
    Expect hlmarks#sign#should_place() to_be_true

    set modifiable
    Expect hlmarks#sign#should_place() to_be_true
  end

  it 'should return false if all buffer type/state are banned'
    let g:hlmarks_ignore_buffer_type = 'hqprm'

    set buftype=help
    Expect hlmarks#sign#should_place() to_be_false

    set buftype=quickfix
    Expect hlmarks#sign#should_place() to_be_false

    set pvw
    Expect hlmarks#sign#should_place() to_be_false

    set ro
    Expect hlmarks#sign#should_place() to_be_false

    set modifiable
    Expect hlmarks#sign#should_place() to_be_false
  end

  it 'should return false if all buffer type/state are banned with upper-case letler'
    let g:hlmarks_ignore_buffer_type = 'HQPRM'

    set buftype=help
    Expect hlmarks#sign#should_place() to_be_false

    set buftype=quickfix
    Expect hlmarks#sign#should_place() to_be_false

    set pvw
    Expect hlmarks#sign#should_place() to_be_false

    set ro
    Expect hlmarks#sign#should_place() to_be_false

    set modifiable
    Expect hlmarks#sign#should_place() to_be_false
  end

end


describe 's:fix_sign_format()'

  before
    call s:Reg({
      \ 'func': 's:fix_sign_format',
      \ 'ms': '%m',
      \ })
  end

  after
    call s:Reg(0)
  end

  it 'should return defualt format if passed empty'
    let func_name = s:Reg('func')
    let ms = s:Reg('ms')

    Expect Call(func_name, '', ms) ==# ms
  end

  it 'should append mark specifier in front if specifier not exits and truncate if needed'
    let func_name = s:Reg('func')
    let ms = s:Reg('ms')

    Expect Call(func_name, '>', ms) ==# ms.'>'
    Expect Call(func_name, '>=', ms) ==# ms.'>'
  end

  it 'should pass through if passed correct valaue'
    let func_name = s:Reg('func')
    let ms = s:Reg('ms')

    Expect Call(func_name, ms, ms) ==# ms
    Expect Call(func_name, ms.'>', ms) ==# ms.'>'
    Expect Call(func_name, '>'.ms, ms) ==# '>'.ms
  end

  it 'should truncate from end if passed exceeded value'
    let func_name = s:Reg('func')
    let ms = s:Reg('ms')

    Expect Call(func_name, ms.'>X', ms) ==# ms.'>'
    Expect Call(func_name, '>X'.ms, ms) ==# '>'.ms
    Expect Call(func_name, '>'.ms.'X', ms) ==# '>'.ms
  end

  it 'should compact mark specifier if passed two or more mark specifier'
    let func_name = s:Reg('func')
    let ms = s:Reg('ms')

    Expect Call(func_name, ms.ms, ms) ==# ms
    Expect Call(func_name, ms.ms.'>', ms) ==# ms.'>'
    Expect Call(func_name, '>'.ms.ms, ms) ==# '>'.ms
    Expect Call(func_name, ms.'>'.ms, ms) ==# ms.'>'
    Expect Call(func_name, '>'.ms.'X'.ms, ms) ==# '>'.ms
    Expect Call(func_name, ms.'>'.ms.'X', ms) ==# ms.'>'
  end

end


describe 's:name_sorter()'

  it 'should sort according to list of character order'
    " Note: This is tested in s:reorder_spec().
  end

end


describe 's:definition_bundle()'

  it 'should return currently defined signs as single string crumb'
    let signs = s:define_sign(1)
    let bundle = Call('s:definition_bundle')

    Expect bundle != ''

    for name in signs
      Expect bundle =~# name
    endfor

    call s:define_sign(0)
    call s:Reg(0)
  end

end


describe 's:extract_chars()'

  before
    call s:Reg({'func': 's:extract_chars'})
  end

  after
    call s:Reg(0)
  end

  it 'should extract designated character class from passed strings'
    let target = 'ABCdef123<>.[]'
    let func_name = s:Reg('func')

    Expect Call(func_name, 'lower', target) == 'def'
    Expect Call(func_name, 'upper', target) == 'ABC'
    Expect Call(func_name, 'number', target) == '123'
    Expect Call(func_name, 'symbol', target) == '<>.[]'
  end

  it 'should extract no character from empty string'
    let target = ''
    let func_name = s:Reg('func')

    Expect Call(func_name, 'lower', target) == ''
    Expect Call(func_name, 'upper', target) == ''
    Expect Call(func_name, 'number', target) == ''
    Expect Call(func_name, 'symbol', target) == ''
  end

end


describe 's:extract_definition_names()'

  before
    call s:Reg({
      \ 'func': 's:extract_definition_names',
      \ 'bundle_func': 's:definition_bundle',
      \ 'signs': s:define_sign(1),
      \ })
  end

  after
    call s:define_sign(0)
    call s:Reg(0)
  end

  it 'should extarct sign names from strings by s:definition_bundle()'
    let signs = s:Reg('signs')
    let bundle = Call(s:Reg('bundle_func'))

    let names = Call(s:Reg('func'), bundle, '^'.s:sign_prefix())

    Expect len(names) == len(signs)
    Expect names == signs
  end

  it 'should return empty list if passed empty string'
    let signs = s:Reg('signs')

    let names = Call(s:Reg('func'), '', signs)

    Expect names == []
  end

  it 'should return empty list if no sign name is found'
    let signs = s:Reg('signs')
    let bundle = Call(s:Reg('bundle_func'))

    let names = Call(s:Reg('func'), bundle, '^__never_match__')

    Expect names == []
  end

end


describe 's:extract_sign_specs()'

  before
    call s:Reg({
      \ 'func': 's:extract_sign_specs',
      \ 'bundle_func': 's:sign_bundle',
      \ 'sign_spec_tmpl': {
        \ 'marks': [],
        \ 'others': [],
        \ 'ids': [],
        \ 'order': [],
        \ }
      \ })

    " line-no, id, name
    " Note: Signs are placed following order, AND appears in bundle(sign place
    "       buffer=n) with INVERSE order.
    call s:Reg({'sign_specs': [
      \ [1, 12, 'SLF_b'],
      \ [1, 11, 'SLF_a'],
      \ [2, 26, 'OTS_2'],
      \ [2, 22, 'SLF_d'],
      \ [2, 21, 'SLF_c'],
      \ [2, 25, 'OTS_1'],
      \ [3, 32, 'OTS_4'],
      \ [3, 31, 'OTS_3'],
      \ ]})

    for spec in s:Reg('sign_specs')
      execute 'sign define '.spec[2]
      execute printf('sign place %s line=%s name=%s buffer=%s', spec[1], spec[0], spec[2], bufnr('%'))
    endfor
  end

  after
    sign unplace *
    for spec in s:Reg('sign_specs')
      execute 'sign undefine '.spec[2]
    endfor

    call s:Reg(0)
  end

  it 'should return empty spec-hash if no sign in buffer (line-no specified)'
    sign unplace *
    let func_name = s:Reg('func')
    let bundle = Call(s:Reg('bundle_func'), bufnr('%'))
    let expected = s:Reg('sign_spec_tmpl')

    Expect Call(func_name, bundle, 1, '^SLF') == expected
  end

  it 'should extract spec-hash contains both(self,others) signs (line-no specified)'
    let func_name = s:Reg('func')
    let bundle = Call(s:Reg('bundle_func'), bufnr('%'))
    let expected = {
      \ 'marks':  [ [22, 'SLF_d'], [21, 'SLF_c'] ],
      \ 'others': [ [26, 'OTS_2'], [25, 'OTS_1'] ],
      \ 'ids':    [ 26, 22, 21, 25 ],
      \ 'order':  [ 0, 1, 1, 0 ],
      \ }

    Expect Call(func_name, bundle, 2, '^SLF') == expected
  end

  it 'should extract spec-hash only contains only signs of self (line-no specified)'
    let func_name = s:Reg('func')
    let bundle = Call(s:Reg('bundle_func'), bufnr('%'))
    let expected = {
      \ 'marks':  [ [12, 'SLF_b'], [11, 'SLF_a'] ],
      \ 'others': [],
      \ 'ids':    [ 12, 11 ],
      \ 'order':  [ 1, 1 ],
      \ }

    Expect Call(func_name, bundle, 1, '^SLF') == expected
  end

  it 'should extract spec-hash only contains only signs of others (line-no specified)'
    let func_name = s:Reg('func')
    let bundle = Call(s:Reg('bundle_func'), bufnr('%'))
    let expected = {
      \ 'marks':  [],
      \ 'others': [ [32, 'OTS_4'], [31, 'OTS_3'] ],
      \ 'ids':    [ 32, 31 ],
      \ 'order':  [ 0, 0 ],
      \ }

    Expect Call(func_name, bundle, 3, '^SLF') == expected
  end

  it 'should extract all signs as line-no => spec-hash (line-no = 0)'
    let func_name = s:Reg('func')
    let bundle = Call(s:Reg('bundle_func'), bufnr('%'))
    let expected = {
      \ '1': {
        \ 'marks':  [ [12, 'SLF_b'], [11, 'SLF_a'] ],
        \ 'others': [],
        \ 'ids':    [ 12, 11 ],
        \ 'order':  [ 1, 1 ],
        \ },
      \ '2': {
        \ 'marks':  [ [22, 'SLF_d'], [21, 'SLF_c'] ],
        \ 'others': [ [26, 'OTS_2'], [25, 'OTS_1'] ],
        \ 'ids':    [ 26, 22, 21, 25 ],
        \ 'order':  [ 0, 1, 1, 0 ],
        \ },
      \ '3': {
        \ 'marks':  [],
        \ 'others': [ [32, 'OTS_4'], [31, 'OTS_3'] ],
        \ 'ids':    [ 32, 31 ],
        \ 'order':  [ 0, 0 ],
        \ }
      \ }

    Expect Call(func_name, bundle, 0, '^SLF') == expected
  end

end


describe 's:extract_sign_ids()'

  before
    let signs = s:define_sign(1)

    call s:Reg({
      \ 'func': 's:extract_sign_ids',
      \ 'bundle_func': 's:sign_bundle',
      \ 'ids': s:place_sign(signs),
      \ })
  end

  after
    call s:place_sign(0)
    call s:define_sign(0)
    call s:Reg(0)
  end

  it 'should return empty list if no sign in buffer'
    call s:place_sign(0)
    let bundle = Call(s:Reg('bundle_func'), bufnr('%'))

    let ids = Call(s:Reg('func'), bundle, '^'.s:sign_prefix())

    Expect len(ids) == 0
  end

  it 'should extract id of sign matched passed pattern from strings by s:sign_bundle()'
    let bundle = Call(s:Reg('bundle_func'), bufnr('%'))
    let expected = deepcopy(s:Reg('ids'), 1)

    let ids = Call(s:Reg('func'), bundle, '^'.s:sign_prefix())

    Expect len(ids) == len(expected)

    call sort(ids)
    call sort(expected)

    Expect ids == expected
  end

  it 'should extract all id of sign if passed empty pattern'
    let bundle = Call(s:Reg('bundle_func'), bufnr('%'))
    let expected = deepcopy(s:Reg('ids'), 1)

    let ids = Call(s:Reg('func'), bundle, '')

    call sort(ids)
    call sort(expected)

    Expect ids == expected
  end

end


describe 's:generate_id()'

  before
    call s:Reg({
      \ 'func': 's:generate_id',
      \ 'signs': s:define_sign(1),
      \ })
  end

  after
    call s:define_sign(0)
    call s:Reg(0)
  end

  it 'should generate id=1 if no sign in buffer'
    let func_name = s:Reg('func')

    Expect Call(func_name) == 1
  end

  it 'should generate next number of max id in buffer'
    let func_name = s:Reg('func')
    let max_id = 10

    for id in [7, max_id, 1]
      execute printf('sign place %s line=%s name=%s buffer=%s', id, 1, s:Reg('signs')[0], bufnr('%'))
    endfor

    Expect Call(func_name) == max_id + 1
  end

  it 'should random and less than 100000 number if max number exceeded 100000'
    let func_name = s:Reg('func')
    let max_id = 100010

    execute printf('sign place %s line=%s name=%s buffer=%s', max_id, 1, s:Reg('signs')[0], bufnr('%'))

    Expect Call(func_name) <= 100000
  end

end


describe 's:place()'

  it 'should place signs according to passed specs'
    let sign_names = s:define_sign(1)

    let sign_specs = []
    let id = 1
    for name in sign_names
      call add(sign_specs, [id, name])
      let id += 1
    endfor

    call Call('s:place', 1, sign_specs)

    call Expect_Sign(sign_names, 1, 1)

    call s:place_sign(0)
    call s:define_sign(0)
  end

end


describe 's:remove_with_ids()'

  before
    call s:Local(1)
    call s:Local({'prefix': s:sign_prefix()})

    let signs = s:define_sign(1)

    call s:Reg({
      \ 'signs': signs,
      \ 'ids': s:place_sign(signs),
      \})
  end

  after
    call s:place_sign(0)
    call s:define_sign(0)
    call s:Reg(0)
    call s:Local(0)
  end

  it 'should remove sign with designated id in current buffer if no buffer number is designated'
    let signs = s:Reg('signs')

    call Call('s:remove_with_ids', s:Reg('ids')[0:1])

    call Expect_Sign(signs[0:1], 1, 0)
    call Expect_Sign(signs[-1:-1], 1, 1)
  end

  it 'should remove sign with designated id in designated buffer'
    let signs = s:Reg('signs')

    call Call('s:remove_with_ids', s:Reg('ids')[0:1], bufnr('%'))

    call Expect_Sign(signs[0:1], 1, 0)
    call Expect_Sign(signs[-1:-1], 1, 1)
  end

end


describe 's:reorder_spec()'

  before
    call s:StashGlobal(1)
    call s:Local(1)
    call s:Local({'prefix': 'SLF_'})
    call s:Reg({'sign_spec_tmpl': {
      \ 'marks':  [ [10, 'SLF_a'], [11, 'SLF_b'] ],
      \ 'others': [ [21, 'OTS_2'], [20, 'OTS_1'] ],
      \ 'order':  [ 1, 0, 0, 1 ],
      \ }})

    let g:hlmarks_displaying_marks = 'ba'
  end

  after
    call s:Reg(0)
    call s:Local(0)
    call s:StashGlobal(0)
  end

  it 'should not sort and signs of self are always placed under signs of others'
    let g:hlmarks_sort_stacked_signs = 0
    let g:hlmarks_stacked_signs_order = 0
    let expected = [ [10, 'SLF_a'], [11, 'SLF_b'], [21, 'OTS_2'], [20, 'OTS_1'] ]

    let ordered = Call('s:reorder_spec', s:Reg('sign_spec_tmpl'))
    Expect ordered.ordered == expected
  end

  it 'should sort and signs of self are always placed under signs of others'
    let g:hlmarks_sort_stacked_signs = 1
    let g:hlmarks_stacked_signs_order = 0
    let expected = [ [11, 'SLF_b'], [10, 'SLF_a'], [21, 'OTS_2'], [20, 'OTS_1'] ]

    let ordered = Call('s:reorder_spec', s:Reg('sign_spec_tmpl'))
    Expect ordered.ordered == expected
  end

  it 'should not sort and signs of self/others are placed same order'
    let g:hlmarks_sort_stacked_signs = 0
    let g:hlmarks_stacked_signs_order = 1
    let expected = [ [10, 'SLF_a'], [21, 'OTS_2'], [20, 'OTS_1'], [11, 'SLF_b'] ]

    let ordered = Call('s:reorder_spec', s:Reg('sign_spec_tmpl'))
    Expect ordered.ordered == expected
  end

  it 'should sort and signs of self/others are placed same order'
    let g:hlmarks_sort_stacked_signs = 1
    let g:hlmarks_stacked_signs_order = 1
    let expected = [ [11, 'SLF_b'], [21, 'OTS_2'], [20, 'OTS_1'], [10, 'SLF_a'] ]

    let ordered = Call('s:reorder_spec', s:Reg('sign_spec_tmpl'))
    Expect ordered.ordered == expected
  end

  it 'should not sort and signs of self are always placed above signs of others'
    let g:hlmarks_sort_stacked_signs = 0
    let g:hlmarks_stacked_signs_order = 2
    let expected = [ [21, 'OTS_2'], [20, 'OTS_1'], [10, 'SLF_a'], [11, 'SLF_b'] ]

    let ordered = Call('s:reorder_spec', s:Reg('sign_spec_tmpl'))
    Expect ordered.ordered == expected
  end

  it 'should sort and signs of self are always placed above signs of others'
    let g:hlmarks_sort_stacked_signs = 1
    let g:hlmarks_stacked_signs_order = 2
    let expected = [ [21, 'OTS_2'], [20, 'OTS_1'], [11, 'SLF_b'], [10, 'SLF_a'] ]

    let ordered = Call('s:reorder_spec', s:Reg('sign_spec_tmpl'))
    Expect ordered.ordered == expected
  end

end


describe 's:sign_name_of()'

  it 'should return sign name embeded mark name'
    Expect Call('s:sign_name_of', 'a') == (Ref('s:sign')['prefix']).'a'
  end

end


describe 's:sign_pattern()'

  it 'should return sign_pattern for searching sign'
    Expect Call('s:sign_pattern') == '\C^'.(Ref('s:sign'))['prefix']
  end

end


describe 's:sign_bundle()'

  before
    call s:Reg({
      \ 'func': 's:sign_bundle',
      \ 'signs': s:define_sign(1),
      \ })
    call s:place_sign(s:Reg('signs'))
  end

  after
    call s:place_sign(0)
    call s:define_sign(0)
    call s:Reg(0)
  end

  it 'should return placed sign info in designated buffer as single string crumb'
    let bundle = Call(s:Reg('func'), bufnr('%'))

    Expect bundle != ''
    for sign_name in s:Reg('signs')
      Expect bundle =~# sign_name
    endfor
  end

  it 'should return placed sign info current buffer if no number passed'
    let bundle = Call(s:Reg('func'))

    Expect bundle != ''
    for sign_name in s:Reg('signs')
      Expect bundle =~# sign_name
    endfor
  end

  it 'should return strings not contained sign info if no sign in buffer'
    call s:place_sign(0)
    let bundle = Call(s:Reg('func'), bufnr('%'))

    Expect bundle != ''
    for sign_name in s:Reg('signs')
      Expect bundle !~# sign_name
    endfor
  end

end


describe 's:mark_name_of()'

  it 'should return only mark name from sign name'
    Expect Call('s:mark_name_of', (Ref('s:sign'))['prefix'].'a') == 'a'
  end

end

