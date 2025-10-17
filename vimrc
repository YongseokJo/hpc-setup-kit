" --- Security / per-project vimrcs ---
set exrc
set secure

" --- Basics ---
set nocompatible
set encoding=utf-8
syntax on
set number
inoremap kj <esc>

" --- Search ---
set hlsearch
set incsearch
set ignorecase
set smartcase
set showmatch

" --- Indent / tabs (defaults; see Python override below) ---
set tabstop=2
set softtabstop=2
set shiftwidth=2
set noexpandtab

" --- Visual guides ---
set colorcolumn=110
highlight ColorColumn ctermbg=darkgray

" --- Filetypes / special cases ---
augroup project
  autocmd!
  autocmd BufRead,BufNewFile *.h,*.c,*.cpp set filetype=c.doxygen
augroup END

" --- Python-specific style ---
augroup python_style
  autocmd!
  autocmd BufNewFile,BufRead *.py
        \ set tabstop=4 |
        \ set softtabstop=4 |
        \ set shiftwidth=4 |
        \ set textwidth=79 |
        \ set expandtab |
        \ set autoindent |
        \ set fileformat=unix
augroup END

" --- Whitespace warnings ---
highlight BadWhitespace ctermbg=red guibg=darkred
autocmd BufRead,BufNewFile *.py,*.pyw,*.c,*.h match BadWhitespace /\s\+$/

" --- Folding ---
set foldmethod=indent
set foldlevel=99
nnoremap <space> za

" --- Colors / Airline ---
colorscheme zenburn
let g:airline_powerline_fonts = 1
let g:airline_theme='zenburn'
set t_Co=256
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#left_sep = ' '
let g:airline#extensions#tabline#left_alt_sep = '|'
let g:airline#extensions#tabline#formatter = 'default'

" --- NERDTree ---
let NERDTreeIgnore=['\.pyc$', '\~$']
nnoremap <C-n> :NERDTreeToggle<CR>

" --- SimpylFold / YCM tweaks ---
let g:SimplyFold_docstring_preview=1
let g:ycm_autoclose_preview_window_after_completion=1
nnoremap <leader>g :YcmCompleter GoToDefinitionElseDeclaration<CR>
let python_highlight_all=1

" --- Virtualenv (only if Vim has +python3) ---
if has('python3')
python3 << EOF
import os
if 'VIRTUAL_ENV' in os.environ:
    act = os.path.join(os.environ['VIRTUAL_ENV'], 'bin', 'activate_this.py')
    if os.path.exists(act):
        with open(act) as f:
            code = compile(f.read(), act, 'exec')
        exec(code, {'__file__': act})
EOF
endif

" --- Plugins: Vundle bootstrap (portable) ---
" If Vundle not present, clone it automatically.
if !isdirectory(expand('~/.vim/bundle/Vundle.vim'))
  silent !git clone https://github.com/VundleVim/Vundle.vim ~/.vim/bundle/Vundle.vim
  autocmd VimEnter * PluginInstall | qall
endif

set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
Plugin 'VundleVim/Vundle.vim'           " (new name for gmarik/Vundle.vim)
Plugin 'tmhedberg/SimpylFold'
Plugin 'vim-scripts/indentpython.vim'
if has('python3') && has('patch-9.1.0016')
  Plugin 'ycm-core/YouCompleteMe'
else
	Plugin 'prabirshrestha/asyncomplete.vim'
	Plugin 'prabirshrestha/vim-lsp'
endif
"Plugin 'vim-syntastic/syntastic'
Plugin 'nvie/vim-flake8'
Plugin 'jnurmine/Zenburn'
"Plugin 'altercation/vim-colors-solarized'
Plugin 'preservim/nerdtree'
Plugin 'ctrlpvim/ctrlp.vim'
Plugin 'vim-airline/vim-airline'
Plugin 'vim-airline/vim-airline-themes'
call vundle#end()

try
  colorscheme zenburn
catch /^Vim\%((\a\+)\)\=:E185/
  colorscheme default
endtry

filetype plugin indent on
