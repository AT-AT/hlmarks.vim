# Hlmarks.vim

マークのハイライトと名前の表示して、少しだけ便利な機能を追加したVimプラグインです  
Hlmarks.vim is a Vim plug-in that highlight marks and display that name, and add a little only useful function.

## 特徴

**マークを移動するとハイライトとマーク名も移動します**  
**If you move the mark, highlight and mark name is also moving.**

![マークと移動](https://github.com/AT-AT/hlmarks.vim/raw/master/doc/images/ex_move.gif)  
(`ma` ... `ma`)

**同じ行でもう一度マークするとマークを削除できます**  
**If you mark again on the same line, you can delete the mark.**

![マークの削除](https://github.com/AT-AT/hlmarks.vim/raw/master/doc/images/ex_toggle.gif)  
(`ma` -> `ma`)

**インクリメントにマークすることもできます**  
**You can mark incrementally.**

![インクリメントマーク](https://github.com/AT-AT/hlmarks.vim/raw/master/doc/images/ex_automark.gif)  
(`me` ... `<Leader>mm` ... `<Leader>mm`)

**重なったマークは設定に従って表現され、一度に削除もできます**  
**Overlapping marks are displayed according to setting, enable to remove them at a time.**

![同位置マークの表示と削除](https://github.com/AT-AT/hlmarks.vim/raw/master/doc/images/ex_stack_rm_line.gif)  
(`ma` -> `mb` -> `mc` -> `<Leader>ml`)

**同じバッファ内のマークを一度に削除することができます**  
**You can remove all marks in the same buffer at a time.**

![同一バッファ内のマーク削除](https://github.com/AT-AT/hlmarks.vim/raw/master/doc/images/ex_rm_buffer.gif)  
(`ma` -> `mb` ... `mc` ... `<Leader>mb`)

詳細は[ヘルプドキュメント](doc/hlmarks.jax)を参照してください  
Please refer to the [help documentation](doc/hlmarks.txt) for details.

