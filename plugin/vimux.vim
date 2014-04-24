if exists("g:loaded_vimux") || &cp
  finish
endif
let g:loaded_vimux = 1

command VimuxRunLastCommand :call VimuxRunLastCommand()
command VimuxCloseRunner :call VimuxCloseRunner()
command VimuxZoomRunner :call VimuxZoomRunner()
command VimuxInspectRunner :call VimuxInspectRunner()
command VimuxScrollUpInspect :call VimuxScrollUpInspect()
command VimuxScrollDownInspect :call VimuxScrollDownInspect()
command VimuxInterruptRunner :call VimuxInterruptRunner()
command VimuxPromptCommand :call VimuxPromptCommand()
command VimuxClearRunnerHistory :call VimuxClearRunnerHistory()

function! VimuxRunLastCommand()
  if exists("g:VimuxRunnerIndex")
    call VimuxRunCommand(g:VimuxLastCommand)
  else
    echo "No last vimux command."
  endif
endfunction

function! VimuxRunCommand(command, ...)
  if !exists("g:VimuxRunnerIndex") || _VimuxHasRunner(g:VimuxRunnerIndex) == -1
    call VimuxOpenRunner()
  endif

  let l:autoreturn = 1
  if exists("a:1")
    let l:autoreturn = a:1
  endif

  let resetSequence = _VimuxOption("g:VimuxResetSequence", "q C-u")
  let g:VimuxLastCommand = a:command

  call VimuxSendKeys(resetSequence)
  call VimuxSendText(a:command)

  if l:autoreturn == 1
    call VimuxSendKeys("Enter")
  endif
endfunction

function! VimuxSendText(text)
  call VimuxSendKeys('"'.escape(a:text, '"').'"')
endfunction

function! VimuxSendKeys(keys)
  if exists("g:VimuxRunnerIndex")
    call system("tmate send-keys -t ".g:VimuxRunnerIndex." ".a:keys)
  else
    echo "No vimux runner pane/window. Create one with VimuxOpenRunner"
  endif
endfunction

function! VimuxOpenRunner()
  let nearestIndex = _VimuxNearestIndex()

  if _VimuxOption("g:VimuxUseNearest", 1) == 1 && nearestIndex != -1
    let g:VimuxRunnerIndex = nearestIndex
  else
    if _VimuxRunnerType() == "pane"
      let height = _VimuxOption("g:VimuxHeight", 20)
      let orientation = _VimuxOption("g:VimuxOrientation", "v")
      call system("tmate split-window -p ".height." -".orientation)
    elseif _VimuxRunnerType() == "window"
      call system("tmate new-window")
    endif

    let g:VimuxRunnerIndex = _VimuxTmuxIndex()
    call system("tmate last-"._VimuxRunnerType())
  endif
endfunction

function! VimuxCloseRunner()
  if exists("g:VimuxRunnerIndex")
    call system("tmate kill-"._VimuxRunnerType()." -t ".g:VimuxRunnerIndex)
    unlet g:VimuxRunnerIndex
  endif
endfunction

function! VimuxZoomRunner()
  if exists("g:VimuxRunnerIndex")
    if _VimuxRunnerType() == "pane"
      call system("tmate resize-pane -Z -t ".g:VimuxRunnerIndex)
    elseif _VimuxRunnerType() == "window"
      call system("tmate select-window -t ".g:VimuxRunnerIndex)
    endif
  endif
endfunction

function! VimuxInspectRunner()
  call system("tmate select-"._VimuxRunnerType()." -t ".g:VimuxRunnerIndex)
  call system("tmate copy-mode")
endfunction

function! VimuxScrollUpInspect()
  call VimuxInspectRunner()
  call system("tmate last-"._VimuxRunnerType())
  call VimuxSendKeys("C-u")
endfunction

function! VimuxScrollDownInspect()
  call VimuxInspectRunner()
  call system("tmate last-"._VimuxRunnerType())
  call VimuxSendKeys("C-d")
endfunction

function! VimuxInterruptRunner()
  call VimuxSendKeys("^c")
endfunction

function! VimuxClearRunnerHistory()
  if exists("g:VimuxRunnerIndex")
    call system("tmate clear-history -t ".g:VimuxRunnerIndex)
  endif
endfunction

function! VimuxPromptCommand()
  let l:command = input(_VimuxOption("g:VimuxPromptString", "Command? "))
  call VimuxRunCommand(l:command)
endfunction

function! _VimuxTmuxSession()
  return _VimuxTmuxProperty("#S")
endfunction

function! _VimuxTmuxIndex()
  if _VimuxRunnerType() == "pane"
    return _VimuxTmuxPaneIndex()
  else
    return _VimuxTmuxWindowIndex()
  end
endfunction

function! _VimuxTmuxPaneIndex()
  return _VimuxTmuxProperty("#I.#P")
endfunction

function! _VimuxTmuxWindowIndex()
  return _VimuxTmuxProperty("#I")
endfunction

function! _VimuxNearestIndex()
  let panes = split(system("tmate list-"._VimuxRunnerType()."s"), "\n")

  for pane in panes
    if match(pane, "(active)") == -1
      return split(pane, ":")[0]
    endif
  endfor

  return -1
endfunction

function! _VimuxRunnerType()
  return _VimuxOption("g:VimuxRunnerType", "pane")
endfunction

function! _VimuxOption(option, default)
  if exists(a:option)
    return eval(a:option)
  else
    return a:default
  endif
endfunction

function! _VimuxTmuxProperty(property)
    return substitute(system("tmate display -p '".a:property."'"), '\n$', '', '')
endfunction

function! _VimuxHasRunner(index)
  return match(system("tmate list-"._VimuxRunnerType()."s -a"), a:index.":")
endfunction
