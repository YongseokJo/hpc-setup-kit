" --- Security / per-project vimrcs ---
set exrc
set secure

" --- Basics ---
set nocompatible
set encoding=utf-8
syntax on
set number
inoremap kj <esc>
set pastetoggle=<F2>

" --- Truecolor (24-bit), including inside tmux ---
if exists('+termguicolors')
  " These let termguicolors work through tmux (tmux.conf advertises Tc).
  let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
  let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
  set termguicolors
endif

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
" Claude warm theme. Background stays transparent (follows the terminal /
" Ghostty color); only accents + syntax are tuned to the clay/coral palette
" shared with tmux + starship. Defined here, applied after Vundle loads.
set background=dark

function! s:ClaudeColors() abort
  " Transparent: the editor adopts the terminal background. Foreground colors
  " switch with &background so syntax reads on both a cream and a dark terminal.
  if &background ==# 'dark'
    let l:fg='#e8e6dc' | let l:muted='#8a8a82' | let l:op='#b5b3aa'
    let l:clay='#d97757' | let l:terra='#e0a088' | let l:sage='#a3b86a'
    let l:gold='#d9a85f' | let l:teal='#7db5c0' | let l:plum='#cf9bb0'
    let l:dim='#62625c' | let l:sel='#45433f' | let l:col='#30302e' | let l:pop='#3a3a37'
  else
    let l:fg='#3d3d3a' | let l:muted='#8a8a85' | let l:op='#6b6b66'
    let l:clay='#c15f3c' | let l:terra='#b5654d' | let l:sage='#5f7a2e'
    let l:gold='#a87b1f' | let l:teal='#2f7d8a' | let l:plum='#8b4789'
    let l:dim='#aaaaa0' | let l:sel='#e7d6cc' | let l:col='#f2efe6' | let l:pop='#ece7d8'
  endif
  " Keep these structural groups transparent so the terminal shows through.
  highlight Normal       guibg=NONE ctermbg=NONE
  highlight SignColumn   guibg=NONE ctermbg=NONE
  highlight CursorLine   gui=underline cterm=underline guibg=NONE ctermbg=NONE
  exe 'highlight NonText      guibg=NONE guifg='.l:dim
  exe 'highlight EndOfBuffer  guibg=NONE guifg='.l:dim
  exe 'highlight VertSplit    guibg=NONE guifg='.l:pop
  " Syntax — clay/coral for the important tokens, warm earth tones elsewhere.
  exe 'highlight Comment      gui=italic guifg='.l:muted
  exe 'highlight Identifier   guifg='.l:fg
  exe 'highlight Operator     guifg='.l:op
  exe 'highlight Statement    gui=bold guifg='.l:clay
  exe 'highlight Keyword      gui=bold guifg='.l:clay
  exe 'highlight Conditional  guifg='.l:clay
  exe 'highlight Repeat       guifg='.l:clay
  exe 'highlight Boolean      guifg='.l:clay
  exe 'highlight Function     guifg='.l:terra
  exe 'highlight Special      guifg='.l:terra
  exe 'highlight String       guifg='.l:sage
  exe 'highlight Constant     guifg='.l:gold
  exe 'highlight Number       guifg='.l:gold
  exe 'highlight Type         guifg='.l:teal
  exe 'highlight PreProc      guifg='.l:plum
  " UI accents.
  exe 'highlight LineNr       guibg=NONE ctermbg=NONE guifg='.l:dim
  exe 'highlight CursorLineNr gui=bold guifg='.l:clay
  exe 'highlight Visual       guifg=NONE guibg='.l:sel
  exe 'highlight Search       gui=bold guifg='.l:clay.' guibg='.l:pop
  exe 'highlight IncSearch    guifg=#faf9f5 guibg='.l:clay
  exe 'highlight MatchParen   gui=bold,underline guibg=NONE guifg='.l:clay
  exe 'highlight Pmenu        guifg='.l:fg.' guibg='.l:pop
  exe 'highlight PmenuSel     guifg=#faf9f5 guibg='.l:clay
  exe 'highlight ColorColumn  guibg='.l:col
  exe 'highlight Folded       guifg='.l:muted.' guibg='.l:col
  exe 'highlight StatusLine   gui=bold guifg=#faf9f5 guibg='.l:clay
  exe 'highlight StatusLineNC guifg='.l:muted.' guibg='.l:pop
  highlight Todo  guifg=#faf9f5 guibg=#c15f3c gui=bold
  highlight Error guifg=#faf9f5 guibg=#b83d2e
endfunction

let g:airline_powerline_fonts = 1
let g:airline_theme='sol'
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

" Apply the Claude theme now, and re-apply whenever a colorscheme loads
" (e.g. a plugin sets one) so the warm accents always win.
call s:ClaudeColors()
augroup ClaudeTheme
  autocmd!
  autocmd ColorScheme * call s:ClaudeColors()
augroup END

filetype plugin indent on

highlight Normal ctermbg=NONE guibg=NONE
highlight NonText ctermbg=NONE guibg=NONE
highlight LineNr ctermbg=NONE guibg=NONE
highlight SignColumn ctermbg=NONE guibg=NONE
highlight EndOfBuffer ctermbg=NONE guibg=NONE
