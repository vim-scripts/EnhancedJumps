" Changes.vim: Enhanced change list navigation commands.
"
" DEPENDENCIES:
"   - EnhancedJumps/Common.vim autoload script
"   - ingo/msg.vim autoload script
"   - ingo/window/dimensions.vim autoload script
"
" Copyright: (C) 2012-2015 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   3.03.007	24-Feb-2015	Minor: Use ingo#compat#abs().
"   3.02.006	05-May-2014	Use ingo#msg#WarningMsg().
"   3.01.005	14-Jun-2013	Use ingo/msg.vim.
"   3.01.004	05-Jun-2013	Handle it when the :changes command sometimes
"				outputs just the header without a following ">"
"				marker by catching the plugin exception in
"				EnhancedJumps#Changes#GetJumps() and returning
"				an empty List instead. This will cause the
"				callers to fall back on the default g; / g,
"				commands, which will then report the "E664:
"				changelist is empty" error.
"   3.01.003	08-Apr-2013	Move ingowindow.vim functions into ingo-library.
"   3.00.002	09-Feb-2012	Modify s:FilterNearJumps() algorithm.
"	001	08-Feb-2012	file creation
let s:save_cpo = &cpo
set cpo&vim

function! s:FilterNearJumps( jumps, startLnum, endLnum, nearHeight )
"****D echomsg '####' a:startLnum a:endLnum
    let l:farJumps = []
    let l:prevParsedJump = EnhancedJumps#Common#ParseJumpLine('')
    let l:prevParsedJump.lnum = -1 * (a:nearHeight + 1)
    let l:lastLnum = 0

    for l:i in range(len(a:jumps))
	let l:currentParsedJump = EnhancedJumps#Common#ParseJumpLine(a:jumps[l:i])
	" Include the current jump if it's outside the currently visible range,
	" and more than a:nearHeight lines away from the previous jump or from
	" the last accepted jump.
"****D echomsg '****' l:currentParsedJump.lnum l:prevParsedJump.lnum l:lastLnum
	if (
	\   l:currentParsedJump.lnum < a:startLnum ||
	\   l:currentParsedJump.lnum > a:endLnum
	\) && (
	\   ingo#compat#abs(l:currentParsedJump.lnum - l:prevParsedJump.lnum) > a:nearHeight ||
	\   ingo#compat#abs(l:currentParsedJump.lnum - l:lastLnum) > a:nearHeight
	\)
	    call add(l:farJumps, a:jumps[l:i])
	    let l:lastLnum = l:currentParsedJump.lnum
"****D echomsg '**** accept'
	endif
	let l:prevParsedJump = l:currentParsedJump
    endfor
"****D echo "****\n" join(l:farJumps, "\n")
    return l:farJumps
endfunction
function! EnhancedJumps#Changes#GetJumps( isNewer )
    let [l:startLnum, l:endLnum] = ingo#window#dimensions#DisplayedLines()
    let l:nearHeight = winheight(0)

    try
	return s:FilterNearJumps(
	\   EnhancedJumps#Common#SliceJumpsInDirection(
	\       EnhancedJumps#Common#GetJumps('changes'),
	\       a:isNewer
	\   ),
	\   l:startLnum, l:endLnum, l:nearHeight
	\)
    catch /^EnhancedJumps:/
	return []
    endtry
endfunction

function! s:warn( warningmsg )
    redraw	" After the jump, a redraw is pending. Do it now or the message may vanish.
    call ingo#msg#WarningMsg(a:warningmsg)
endfunction
function! s:DoJump( count, isNewer )
    if a:count == 0
	execute "normal! \<C-\>\<C-n>\<Esc>"
	return 0
    endif
"****D echomsg '****' a:count . (a:isNewer ? 'g,' : 'g;')
    try
	execute 'normal!' a:count . (a:isNewer ? 'g,' : 'g;')

	" When typed, g,/g; open the fold at the jump target, but inside a
	" mapping or :normal this must be done explicitly via 'zv'.
	normal! zv

	return 1
    catch /^Vim\%((\a\+)\)\=:/
	" A Vim error occurs when already at the start / end of the changelist.
	call ingo#msg#VimExceptionMsg()
	return 0
    endtry
endfunction

function! EnhancedJumps#Changes#Jump( isNewer, isFallbackToNearChanges )
    let l:jumpDirection = (a:isNewer ? 'newer' : 'older')
    let l:count = v:count1
    let l:jumps = EnhancedJumps#Changes#GetJumps(a:isNewer)
    if empty(l:jumps)
	if a:isFallbackToNearChanges
	    " Perform the [count]'th near jump.
	    if s:DoJump(l:count, a:isNewer)
		" Only print the warning when the jump was successful; it may
		" have already errored out with "At start / end of changelist".
		call s:warn(printf('No %s far change', l:jumpDirection))
	    endif
	else
	    call ingo#msg#ErrorMsg(printf('No %s far change', l:jumpDirection))
	    " Still execute the a zero-jump command to cause the customary beep.
	    call s:DoJump(0, a:isNewer)
	endif

	return
    endif

"****D for j in l:jumps | echomsg j | endfor
    let l:isFallbackNearJump = 0
    let l:targetJump = get(l:jumps, l:count - 1, '')
    if empty(l:targetJump)
	" Jump to the last available far jump, like the original 999g, jumps to
	" the last change.
	let l:targetJump = get(l:jumps, -1, '')
	let l:isFallbackNearJump = 1
    endif

    " Because of filtering the count for the jump command does not correspond to
    " the given count and must be retrieved from the jump line.
    let l:jumpCount = EnhancedJumps#Common#ParseJumpLine(l:targetJump).count
"****D echomsg '****' l:count l:jumpCount
    if s:DoJump(l:jumpCount, a:isNewer) && l:isFallbackNearJump
	" Only print the warning when the jump was successful; it may
	" have already errored out with "At start / end of changelist".
	call s:warn(printf('No more %d %s far changes', l:count, l:jumpDirection))
    endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
