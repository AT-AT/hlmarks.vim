"
" Common test helpers
"   ver: 2015-07-08
"

"
" For testing this helper self.
"
let s:test_helpers = {}
let s:test_helpers_func = {'testvar': 0}
function! s:test_helpers_func.test()
  let self.testvar = 1
endfunction
function! test_helpers#scope()
  return s:
endfunction

"
" Capture result of execution command.
"
" Param:  [String] cmd: command
" Param:  [Number] (a:1) specifier for result type
" Return: [String, List] captured strings(a:1=0) or list(a:1=1/default)
"
function! _Grab_(cmd, ...)
  redir => crumb
    silent execute a:cmd
  redir END

  let want_array = a:0 ? a:1 : 1

  return want_array ? split(crumb, "\n") : crumb
endfunction

"
" Preserve/Refer/Set/Recover script local variable with dictionary.
"
" Param:  [String] value_name: local variable name for vspec#ref()
" Param:  [Dict, String, 0, 1] subject: see below
"           Dict    => Set (used as updating)
"           String  => Refer (used as key for dict)
"           0       => Recover
"           1       => Preserve
" Param:  [String] (a:1) used as name of stack if non-empty string is passed
"           Note: If designate this at preserving, must designate same name in
"                 other operation(Refer/Set/Recover).
" Return: [Any] value in local variable(only if subject is string)
" Example:
"   Preserve values at first.
"     call _HandleLocalDict_('s:foo', 1)
"   Set/Refer value.
"     call _HandleLocalDict_('s:foo', {'bar': 'baz'})
"     let x = _HandleLocalDict_('s:foo', 'bar')
"   Recover at end of each test.
"     call _HandleLocalDict_('s:foo', 0)
" Note: Duplication call of preservation do not affect process.
" Note: For convenience, define wrapper function in each test file.
"   function! s:HL(s)
"     call _HandleLocalDict_('s:foo', s, '__long_specific_stack_name_here__')
"   endfunction
"
function! _HandleLocalDict_(value_name, subject, ...)
  let stack_name_base = 'testing_common_helper_stack_registry'
  let param = a:0 ? a:1 : ''
  if type(param) == type('') && param != ''
    let stack_name_base = param
  endif

  let stack_name = stack_name_base . '_' . split(a:value_name, ':')[-1]
  let subject_type = type(a:subject)
  let local = Ref(a:value_name)

  if type(local) != type({})
    throw 'Invalid local variable type.'
  endif

  " Preserve
  if subject_type == type(1) && a:subject == 1
    if !has_key(g:, stack_name)
      let g:{stack_name} = deepcopy(local, 1)
    endif

  " Recover
  elseif subject_type == type(1) && a:subject == 0
    call Set(a:value_name, g:{stack_name})
    unlet g:{stack_name}

  " Set
  elseif subject_type == type({})
    let local = deepcopy(local, 1)
    for [key, value] in items(a:subject)
      let local[key] = value
      unlet value
    endfor
    call Set(a:value_name, local)

  " Refer
  elseif subject_type == type('')
    " DO NOT copy local because it may be used to access function in dictionary.
    return has_key(local, a:subject) ? local[a:subject] : local

  else
    throw 'Invalid argument.'
  endif
endfunction

"
" Register/Refer/Remove values in a dictinary using global variable.
"
" Param:  [String] prefix: strings that prepend to variable name
" Param:  [Dict, String, 0] subject: see below
"           Dict    => Register (g:prefix+key = value)
"           String  => Refer (g:prefix+subject)
"           0       => Remove
" Return: [Any] registered value(only if subject is string)
" Example:
"   Register values(as many times as needed).
"     call _Reg_('__t__', {'foo': 'bar', ...})
"   Refer when needed.
"     let x = _Reg_('__t__', 'foo')
"   Remove at end of each test.
"     call _Reg_(0)
" Note: For convenience, define wrapper method in each test file.
"   function! s:R(s)
"     return _Reg_('__long_specific_prefix_here__', s)
"   endfunction
"
function! _Reg_(prefix, subject)
  let subject_type = type(a:subject)

  " Register
  if subject_type == type({})
    for [key, value] in items(a:subject)
      let g:{a:prefix}{key} = deepcopy(value, 1)
      unlet value
    endfor

  " Refer
  elseif subject_type == type('')
    return get(g:, a:prefix . a:subject, '')

  " Remove
  elseif subject_type == type(1) && a:subject == 0
    for g_key in keys(g:)
      if stridx(g_key, a:prefix) == 0
        unlet g:{g_key}
      endif
    endfor

  else
    throw 'Invalid argument.'
  endif
endfunction

"
" Preserve/Recover global variable starts with designated prefix.
"
" Param:  [String, 0] subject: see below
"           String  => Preserve (used for prefix that matches in front of variable)
"           0       => Recover
" Param:  [String] (a:1) used as name of stash if non-empty string is passed
"           Note that if designate this, must designate same name in recover.
" Example:
"   Preserve values at first.
"     call _Stash_('plugin_foo_')
"   Change value.
"     let g:plugin_foo_x = 'bar'
"   Recover at end of each test.
"     call _Stash_(0)
" Note: If use specific stash name, define wrapper function in each test file.
"   function! s:S(s)
"     call _Stash_(s, '__long_specific_stash_name_here__')
"   endfunction
"
function! _Stash_(subject, ...)
  let stash_name = 'testing_common_helper_stash_registry'
  let param = a:0 ? a:1 : ''
  if type(param) == type('') && param != ''
    let stash_name = param
  endif

  " Stash
  if type(a:subject) == type('') && a:subject != ''
    let stash = {}
    for [key, value] in items(g:)
      if stridx(key, a:subject) == 0
        let stash[key] = deepcopy(value, 1)
      endif
      unlet value
    endfor
    let g:{stash_name} = stash

  " Revert
  elseif type(a:subject) == type(1) && a:subject == 0
    for [key, value] in items(g:{stash_name})
      let g:{key} = value
      unlet value
    endfor
    unlet g:{stash_name}

  else
    throw 'Invalid argument.'
  endif
endfunction

