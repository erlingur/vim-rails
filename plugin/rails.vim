" rails.vim - Detect a rails application
" Author:       Tim Pope <http://tpo.pe/>
" GetLatestVimScripts: 1567 1 :AutoInstall: rails.vim

" Install this file as plugin/rails.vim.

if exists('g:loaded_rails') || &cp || v:version < 800
  finish
endif
let g:loaded_rails = 1

" Turn on $LOAD_PATH detection in the ruby ftplugin
if !exists('g:ruby_exec')
  let g:ruby_exec = 1
endif

" Utility Functions {{{1

function! s:error(str)
  echohl ErrorMsg
  echomsg a:str
  echohl None
  let v:errmsg = a:str
endfunction

let s:slash = exists('+shellslash') ? '\' : '/'
function! s:IsAbs(path) abort
  return tr(a:path, s:slash, '/') =~# '^/\|^\a\+:'
endfunction

" }}}1
" Detection {{{1

function! RailsDetect(...) abort
  if exists('b:rails_root')
    return 1
  endif
  if a:0
    let path = a:1
  elseif &l:buftype =~# '^\%(nowrite\)\=$' && len(@%) || &l:buftype =~# '^\%(nofile\|acwrite\)' && s:IsAbs(@%)
    let path = @%
  else
    return
  endif
  if !s:IsAbs(path)
    let s = exists('+shellslash') && !&shellslash ? '\' : '/'
    let path = substitute(getcwd(), '\' . s . '\=$', s, '') . path
  endif
  let path = substitute(path, '[' . s:slash . '/]$', '', '')
  try
    if exists('*ExcludeBufferFromDiscovery') && ExcludeBufferFromDiscovery(file, 'projectionist')
      return
    endif
  catch
  endtry

  if exists('*ProjectionistHas')
    let previous = ''
    while path !=# previous && path !~# '^\.\=$\|^[\/][\/][^\/]*$'
      if ProjectionistHas('config/environment.rb&app/', path)
        let b:rails_root = path
        return 1
      endif
      let previous = path
      let path = fnamemodify(path, ':h')
    endwhile
    return 0
  endif
  let file = findfile('config/environment.rb', escape(path, ', ').';')
  if !empty(file) && isdirectory(fnamemodify(file, ':p:h:h') . '/app')
    let b:rails_root = fnamemodify(file, ':p:h:h')
    return 1
  endif
endfunction

function! s:LogDetect() abort
  let path = matchstr(get(w:, 'quickfix_title'), '\<cgetfile \zs.*\ze[\\/]log[\\/].*.log$')
  if !empty(path) && filereadable(path . '/config/environment.rb') && isdirectory(path . '/app')
    let b:rails_root = path
    setlocal filetype=railslog
  endif
endfunction

" }}}1
" Initialization {{{1

if !exists('g:did_load_ftplugin')
  filetype plugin on
endif
if !exists('g:loaded_projectionist')
  runtime! plugin/projectionist.vim
endif

augroup railsPluginDetect
  autocmd!

  autocmd BufNewFile,BufReadPost *
        \ if RailsDetect() && empty(&filetype) |
        \   call rails#buffer_setup() |
        \ endif
  autocmd VimEnter *
        \ if get(g:, 'rails_vim_enter', get(g:, 'projectionist_vim_enter', 1)) &&
        \     argc() == 0 && RailsDetect(getcwd()) |
        \   call rails#buffer_setup() |
        \ endif
  autocmd FileType netrw
        \ if RailsDetect(get(b:, 'netrw_curdir', @%)) |
        \ endif
  autocmd FileType * if RailsDetect() | call rails#buffer_setup() | endif

  autocmd BufNewFile,BufReadPost *.rjs,*.rxml,*.builder,*.jbuilder,*.ruby
        \ if &filetype !=# 'ruby' | set filetype=ruby | endif
  autocmd BufNewFile,BufReadPost *.turbo_stream.erb
        \ if &filetype !=# 'eruby.html' | set filetype=eruby.html | endif
  autocmd BufReadPost *.log if RailsDetect() | set filetype=railslog | endif

  autocmd FileType qf call s:LogDetect()

  autocmd User ProjectionistDetect
        \ if RailsDetect(get(g:, 'projectionist_file', '')) |
        \   call projectionist#append(b:rails_root,
        \     {'*': {"console": rails#app().static_rails_command('console')}}) |
        \ endif
augroup END

command! -bang -bar -nargs=* -range=-1 -complete=customlist,rails#complete_rails Rails execute rails#command(<bang>0, '<mods>', <count>, <q-args>)

" }}}1
" dadbod.vim support {{{1

call extend(g:, {'db_adapters': {}}, 'keep')
call extend(g:db_adapters, {
      \ 'oracle-enhanced': 'oracle',
      \ 'mysql2': 'mysql',
      \ 'sqlite3': 'sqlite'}, 'keep')

let g:db_adapter_rails = 'rails#db_'

" }}}1
" abolish.vim support {{{1

augroup railsPluginAbolish
  autocmd!
  autocmd VimEnter * call s:abolish_setup()
augroup END

function! s:abolish_setup()
  if exists('g:Abolish') && has_key(g:Abolish,'Coercions')
    if !has_key(g:Abolish.Coercions,'l')
      let g:Abolish.Coercions.l = function('s:abolish_l')
    endif
    if !has_key(g:Abolish.Coercions,'t') || string(g:Abolish.Coercions.t) =~# "'<SNR>[0-9]*_titlecase'"
      let g:Abolish.Coercions.t = function('s:abolish_t')
    endif
  endif
endfunction

function! s:abolish_l(word)
  let singular = rails#singularize(a:word)
  return a:word ==? singular ? rails#pluralize(a:word) : singular
endfunction

function! s:abolish_t(word)
  if a:word =~# '\u'
    return rails#pluralize(rails#underscore(a:word))
  else
    return rails#singularize(rails#camelize(a:word))
  endif
endfunction

" }}}1
" vim:set sw=2 sts=2:
