"
" Check mark existence.
"
function! Expect_Mark(marks, should_present)
  let marks = type(a:marks) == v:t_list ? a:marks : split(a:marks, '\zs')
  let bundle = _Grab_('marks')
  for name in marks
    if a:should_present
      let matched = []
      for crumb in bundle
        if crumb =~# '\v^\s+'.escape(name, '.^[]<>{}()').'\s+\d'
          call add(matched, name)
          break
        endif
      endfor
      " Inspector
      if matched == []
        Expect name == '(debug)'
      endif
      Expect len(matched) == 1
    else
      for crumb in bundle
        Expect crumb !~# '\v^\s+'.escape(name, '.^[]{}()').'\s+\d'
      endfor
    endif
  endfor
endfunction

"
" Check sign exsitence.
"
function! Expect_Sign(signs, line_no, should_present)
  " In bundle, new->old order ...
  let bundle = _Grab_('sign place buffer=' . bufnr('%'))

  if a:should_present
    let signs = deepcopy(a:signs, 1)
    " ... so stacked name to this new->old order.
    let matched_signs = []
    for crumb in bundle
      let matched = ''
      for name in signs
        if crumb =~# '\vline\='.a:line_no.'.+name\='.escape(name, '.^[]{}()')
          let matched = name
          break
        endif
      endfor
      if !empty(matched)
        let idx = index(signs, matched)
        call remove(signs, idx, idx)
        call add(matched_signs, matched)
      endif
    endfor
    Expect len(matched_signs) == len(a:signs)
    " To old->new
    call reverse(matched_signs)
    return matched_signs
  else
    for name in a:signs
      for crumb in bundle
        Expect crumb !~# '\vline\='.a:line_no.'.+name\='.escape(name, '.^[]{}()')
      endfor
    endfor
  endif
endfunction

