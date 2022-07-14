execute 'source ' . expand('%:p:h') . '/t/_common/test_helpers.vim'
execute 'source ' . expand('%:p:h') . '/t/_common/local_helpers.vim'

runtime! plugin/hlmarks.vim

call vspec#hint({'scope': 'hlmarks#cache#scope()', 'sid': 'hlmarks#cache#sid()'})



describe 'clean()/get()/set()'

  before
    new
  end

  after
    close!
  end

  it 'should handle cache stacked in buffer local values'
    let key = 'test_hlmarks_cache'
    let value = {'foo': 'bar', 'baz': ['qux']}
    let fallback = 'fallback'

    Expect hlmarks#cache#get('_never_cached_value_', fallback) == fallback

    call hlmarks#cache#set(key, value)

    Expect hlmarks#cache#get(key, fallback) == value

    call hlmarks#cache#clean()

    Expect hlmarks#cache#get(key, fallback) == fallback
  end

end


describe 's:getbufvar'

  before
    call Register_Val({
      \ 'func': 's:getbufvar',
      \ })

    new
  end

  after
    close!

    call Purge_Val()
  end

  it 'should return fallback value if designated variable is not in buffer'
    let fallback = 'fallback'
    let result = Call(Get_Val('func'), '%', '_never_cached_value_', fallback)

    Expect result == fallback
  end

  it 'should return value stored in designated name'
    let key = 'test_hlmarks_cache'
    let value = {'foo': 'bar', 'baz': ['qux']}
    call setbufvar('%', key, value)
    let result = Call(Get_Val('func'), '%', key, 'fallback')

    Expect result == value
  end

end

