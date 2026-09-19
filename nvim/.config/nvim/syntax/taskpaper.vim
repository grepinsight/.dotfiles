" Vim syntax file
" Language: TaskPaper
" Latest Revision: 16 September 2026
"
" The four item types the app knows about, formatted the way the app formats them: a
" project heading carries weight, a task's dash recedes into a bullet, a note sits
" apart from the tasks around it, and a tag is metadata so it greys. A done task is
" struck through, marker and text alike, with its @done tag left plain.
"
" Every line-level group below starts at column 1, and that is what decides which one
" wins: Vim gives priority to the item defined LAST when two match at the same start
" column. So the order here is load-bearing. Note is the fallback and comes first;
" project outranks it; done outranks everything and comes last. Reordering these
" changes the rendering without changing a single pattern.

if exists("b:current_syntax")
  finish
endif

" The lookbehind is the whole difficulty. A bare /@\w\+/ also paints the domain of
" name@example.com, and half an address is not metadata, so the @ has to open a word:
" start of line, or after whitespace. The optional (...) carries a tag value, as in
" @due(2026-09-16), which reads as one unit and so greys as one.
syn match taskpaperTag /\%(^\|\s\)\@<=@[[:alnum:]_.-]\+\%((\%([^)]*\))\)\=/

" A note is the fallback item type: any non-blank line that is not a task. The \@!
" keeps tasks out, and nothing else needs excluding, because the project match below
" is defined later and therefore wins on the lines it also matches.
syn match taskpaperNote /^\s*\%(-\s\)\@!\S.*$/ contains=taskpaperTag

" A project is a line ending in a colon, optionally followed by tags, as in
" `inbox: @hold`. A line opening with `- ` stays a task even when it ends in a colon,
" because the dash is the explicit marker and a trailing colon there is usually prose.
syn match taskpaperProject /^\s*\%(-\s\)\@!\S.*:\%(\s\+@[[:alnum:]_.-]\+\%((\%([^)]*\))\)\=\)*\s*$/ contains=taskpaperTag

" The marker only, never the text after it. Greying the dash is what makes it read as
" a bullet rather than as a minus sign, and a list of bullets scans as a list.
syn match taskpaperListItem /^\s*-\s/

" Done strikes the whole line, so it has to beat every group above, which is why it is
" last. It does carry `contains=taskpaperTag`, unlike the uniform grey it replaced on
" 2026-09-16: the app draws the line through the item and leaves `@done(2026-09-16)`
" itself unstruck, and containment is what produces that, because a contained group is
" drawn with its own attributes rather than its container's. taskpaperDonePad below is
" the same trick applied to every whitespace run that is not text. One consequence for tests:
" `synID()` at the tag now answers `taskpaperTag`, so asking "is this line struck" means
" asking `synstack()` whether taskpaperDone is anywhere in the stack.
"
" Three parts, and an adversarial review on 2026-09-16 found a bug in each of the two
" this pattern originally had:
"
"   ^\%(.*)\)\=[^(]*   the tag must not sit inside another tag's value. Consume up to
"                      the last closing paren, then require no opening paren before the
"                      tag, so @note(mention @done here) is text and does not dim.
"   \%(^\|\s\)\@<=     the @ opens a word, the same rule as taskpaperTag.
"   \%([[:alnum:]_.-]\)\@!  the tag NAME ends at `done`. \> was wrong here: it uses
"                      keyword boundaries, and `-` and `.` are not keyword characters,
"                      so @done-later and @done.foo both read as @done and dimmed a
"                      live task. The alphabet has to be the tag alphabet, not Vim's.
syn match taskpaperDone /^\%(.*)\)\=[^(]*\%(^\|\s\)\@<=@done\%([[:alnum:]_.-]\)\@!\%((\%([^)]*\))\)\=.*$/ contains=taskpaperTag,taskpaperDonePad

" The strike has to stop where the words do. A match that starts at column 1 draws the
" line across the indent as well, and on a tab-indented list that grows a rule out to the
" left margin on every done task, which chains the strikes together into one figure and
" reads as a table border rather than as a crossed-out item. Reported 2026-09-16.
"
" So the whitespace runs that are not text are carved out with containment rather than by
" moving the match's start, which keeps the column-1 precedence rule at the top of this
" file true. Three alternations, and the third is the one that is easy to miss:
"
"   ^\s\+          the indent.
"   \s\+$          the mirror defect at the other end.
"   \s\+\%(@...\)\@=  the gap in front of a tag. Without it the strike runs from the
"                  last word into the tag it stops at, and a reader sees one unbroken
"                  line across `@important @done`, which is the whole reason the tags
"                  looked crossed out in the report.
"
" The lookahead is what keeps this from cutting the strike at every space: a gap between
" two words carries the line, a gap in front of metadata does not. `contained` makes the
" unanchored alternations safe, because the group is unreachable at the top level, so
" `\s\+$` cannot touch a trailing space on a line that is not done.
syn match taskpaperDonePad /^\s\+\|\s\+$\|\s\+\%(@[[:alnum:]_.-]\)\@=/ contained

hi def link taskpaperTag      Comment
hi def link taskpaperListItem Comment

" A project links, note and done carry attributes. The split turns on one question: does
" a standard group already mean this? `Title` means heading, which is what a project is,
" so linking hands the color to the colorscheme instead of hardcoding one here, the same
" reason the greys above are links.
"
" This was bold with no color until 2026-09-18, on the argument that no standard group
" means "body text, but bold". Correct as far as it went, and it made the heading the only
" item type with no color in a file where tags are grey and done items are struck, so it
" read as the one thing that had been left unhighlighted. A heading wants to be found, not
" to blend.
"
" The cost, worth stating because it is invisible until it bites: a link is
" all-or-nothing, so a colorscheme whose `Title` is not bold takes the weight away too.
" Under github_dark, `Title` is #79c0ff and bold; Vim's own default for it is bold as well.
"
" Note and done stay attributes because nothing standard means "body text, but italic" or
" "body text, struck". Done especially: it is struck and NOT recolored, so a done item
" stays as readable as the app renders it.
hi def link taskpaperProject  Title
hi def taskpaperNote    term=italic cterm=italic gui=italic
hi def taskpaperDone    term=strikethrough cterm=strikethrough gui=strikethrough

" Deliberately empty, and it has to be a definition rather than an omission: the group
" exists so that the text it covers is drawn with no attributes at all, which is what
" cancels the container's strike.
hi def taskpaperDonePad term=NONE cterm=NONE gui=NONE

let b:current_syntax = "taskpaper"
