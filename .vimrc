" general settings
set number
map <F1> <Esc>:bprev<CR>
map <F12> <Esc>:bnext<CR>
map <F10> <Esc>:buffers<CR>
map <F11> <Esc>:Explore<CR>

" phpdoc plugin
let g:phpdoc_tags = {
\   'class' : {
\       'author'        :   'Dmytri Kleiner <dmytri.kleiner@jellyfish.co.uk>',
\       'since'         :   strftime('%Y-%m-%d'),
\       'copyright'     :   '(c) ' . strftime('%Y') . ' Jellyfish',
\       'package'       :   'Mfn',
\   },
\   'function' : {
\       'author'        :   'Dmytri Kleiner <dmytri.kleiner@jellyfish.co.uk>',
\       'since'         :   strftime('%Y-%m-%d'),
\   },
\   'property' : {
\       'since'         :   strftime('%Y-%m-%d'),
\       
\   }
\}
