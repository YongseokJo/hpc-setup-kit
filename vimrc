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
set background=light

function! s:ClaudeColors() abort
  " Keep the editor transparent so it adopts the terminal background.
  highlight Normal         guibg=NONE   ctermbg=NONE
  highlight NonText        guifg=#d8d2c4 guibg=NONE ctermbg=NONE
  highlight EndOfBuffer    guifg=#d8d2c4 guibg=NONE ctermbg=NONE
  highlight SignColumn     guibg=NONE   ctermbg=NONE
  " Syntax — warm earth tones, clay for the important tokens.
  highlight Comment        guifg=#8a8a85 gui=italic ctermfg=245
  highlight Constant       guifg=#a87b1f ctermfg=136
  highlight String         guifg=#5f7a2e ctermfg=64
  highlight Number         guifg=#a87b1f ctermfg=136
  highlight Boolean        guifg=#c15f3c ctermfg=166
  highlight Identifier     guifg=#3d3d3a ctermfg=237
  highlight Function       guifg=#b5654d ctermfg=131
  highlight Statement      guifg=#c15f3c gui=bold ctermfg=166
  highlight Keyword        guifg=#c15f3c gui=bold ctermfg=166
  highlight Conditional    guifg=#c15f3c ctermfg=166
  highlight Repeat         guifg=#c15f3c ctermfg=166
  highlight Operator       guifg=#6b6b66 ctermfg=242
  highlight PreProc        guifg=#8b4789 ctermfg=132
  highlight Type           guifg=#2f7d8a gui=NONE ctermfg=30
  highlight Special        guifg=#b5654d ctermfg=131
  highlight Todo           guifg=#faf9f5 guibg=#c15f3c gui=bold
  " UI accents.
  highlight LineNr         guifg=#aaaaa0 guibg=NONE ctermfg=247 ctermbg=NONE
  highlight CursorLineNr   guifg=#c15f3c gui=bold ctermfg=166
  highlight CursorLine     gui=underline cterm=underline guibg=NONE ctermbg=NONE
  highlight Visual         guibg=#e7d6cc guifg=NONE ctermbg=224
  highlight Search         guifg=#3d3d3a guibg=#e7d6cc gui=bold ctermfg=237 ctermbg=224
  highlight IncSearch      guifg=#faf9f5 guibg=#c15f3c ctermfg=231 ctermbg=166
  highlight MatchParen     guifg=#c15f3c guibg=NONE gui=bold,underline
  highlight Pmenu          guifg=#3d3d3a guibg=#ece7d8 ctermfg=237 ctermbg=223
  highlight PmenuSel       guifg=#faf9f5 guibg=#c15f3c ctermfg=231 ctermbg=166
  highlight ColorColumn    guibg=#f2efe6 ctermbg=224
  highlight StatusLine     guifg=#faf9f5 guibg=#c15f3c gui=bold
  highlight StatusLineNC   guifg=#6b6b66 guibg=#efece2
  highlight VertSplit      guifg=#d8d2c4 guibg=NONE
  highlight Folded         guifg=#6b6b66 guibg=#efece2 ctermfg=242
  highlight Error          guifg=#faf9f5 guibg=#b83d2e
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
