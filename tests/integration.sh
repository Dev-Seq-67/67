#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
program=${PROGRAM:-$root/src/67}
work=$(mktemp -d /tmp/67-inline-test.XXXXXX)
socket=67-inline-test-$$
export TERM=xterm-256color LANG=C.UTF-8
cleanup() { tmux -L "$socket" kill-server 2>/dev/null || :; }
trap cleanup 0
wait_file() {
    attempts=0
    while [ ! -f "$1" ]; do
        attempts=$((attempts+1))
        if [ "$attempts" -ge 60 ]; then
            tmux -L "$socket" capture-pane -p -S -70 -t test >&2
            printf 'Timeout: %s\n' "$1" >&2; exit 1
        fi
        sleep 0.1
    done
}
check_gif() {
    sleep 0.15
    tmux -L "$socket" capture-pane -p -e -t test > "$work/screen"
    tmux -L "$socket" display-message -p -t test '#{cursor_x} #{cursor_y}' > "$work/coords"
    perl "$root/tests/layout.pl" "$work/screen" "$work/coords"
}
tmux -L "$socket" -f /dev/null new-session -d -s test -x 160 -y 24 /bin/bash --noprofile --norc
tmux -L "$socket" send-keys -t test "cd /tmp; '$program'; printf returned > '$work/returned'" Enter
attempts=0
until [ "$(tmux -L "$socket" display-message -p -t test '#{pane_current_command}')" = zsh ]; do
    attempts=$((attempts+1)); [ "$attempts" -lt 60 ] || exit 1; sleep 0.1
done
check_gif
[ "$(tmux -L "$socket" list-panes -t test | wc -l)" -eq 1 ]
# Review regression: removing PREDISPLAY must also remove its color spans.
for marker in TEST-COMMAND TEST-COMMAND-SECOND; do
    tmux -L "$socket" send-keys -l -t test "echo $marker"
    sleep 0.1
    tmux -L "$socket" send-keys -t test Enter
    sleep 0.2
    tmux -L "$socket" capture-pane -p -e -S -100 -t test > "$work/accepted-$marker"
    perl "$root/tests/accepted-command.pl" "$work/accepted-$marker" "echo $marker"
done
if [ "${REGRESSION_ONLY:-0}" = 1 ]; then
    printf 'Evidence: %s\n' "$work"
    exit 0
fi
for i in 1 2 3 4 5 6 7 8 9; do
    tmux -L "$socket" capture-pane -p -e -t test > "$work/frame-$i"
    sleep 0.1
done
[ "$(sha256sum "$work"/frame-* | cut -d ' ' -f1 | sort -u | wc -l)" -ge 2 ]
printf '%s\n' 'PASS: animation changes frames without a separate pane'
# The same cursor must remain available for input while frames refresh.
cmd="printf '%s' 'typing-works' > '$work/result'"
tmux -L "$socket" send-keys -l -t test "$cmd"
check_gif
# Home/End and deletion use the real line editor, not a custom input loop.
tmux -L "$socket" send-keys -t test C-a
tmux -L "$socket" send-keys -l -t test ':; '
tmux -L "$socket" send-keys -t test C-e
check_gif
tmux -L "$socket" send-keys -t test Enter
wait_file "$work/result"
[ "$(cat "$work/result")" = typing-works ]
check_gif
printf '%s\n' 'PASS: typing, cursor motion and execution never put GIF glyphs in the command'
# Renderer lifecycle must never change $! or kill the user's background jobs.
tmux -L "$socket" send-keys -t test "sleep 30 & print -r -- \$! > '$work/background-pid'" Enter
wait_file "$work/background-pid"
background=$(cat "$work/background-pid")
tmux -L "$socket" send-keys -t test "print -r -- \$! > '$work/background-next'" Enter
wait_file "$work/background-next"
[ "$(cat "$work/background-next")" = "$background" ]
kill -0 "$background"
# Stop/restart from the prompt controls the current session.
tmux -L "$socket" send-keys -t test "67 --stop; printf stopped > '$work/stopped'" Enter
wait_file "$work/stopped"
sleep 0.2
tmux -L "$socket" capture-pane -p -t test > "$work/stopped-screen"
perl -CSDA -ne 'die "GIF still visible after --stop\n" if /[\x{2500}-\x{259f}]/;' "$work/stopped-screen"
tmux -L "$socket" send-keys -t test '67' Enter
check_gif
kill -0 "$background"
tmux -L "$socket" send-keys -t test "kill $background; wait $background 2>/dev/null; print done > '$work/background-done'" Enter
wait_file "$work/background-done"
printf '%s\n' 'PASS: renderer preserves the user background job and $!'
# Long commands wrap below the sprite, never through it.
long=$(printf '%0180d' 0)
tmux -L "$socket" send-keys -l -t test "printf '%s' '$long' > '$work/wrapped'"
sleep 0.2
tmux -L "$socket" capture-pane -p -t test > "$work/wrapped-screen"
tmux -L "$socket" display-message -p -t test '#{cursor_y}' > "$work/wrapped-cursor"
perl -CSDA -e '
 open my $s,"<",$ARGV[0] or die; my @l=<$s>;
 open my $c,"<",$ARGV[1] or die; my $cursor=<$c>;
 my @cat=grep {$l[$_] =~ /[\x{2500}-\x{259f}]/} 0..$#l;
 die "Wrapped command overlaps cat\n" unless @cat==8 && $cat[-1] < $cursor-1;
 die "Command starts on cat row\n" unless $l[$cat[-1]+1] =~ /printf/;
 print "PASS: wrapped command begins below all eight cat rows\n";
' "$work/wrapped-screen" "$work/wrapped-cursor"
tmux -L "$socket" send-keys -t test Enter
wait_file "$work/wrapped"
[ "$(cat "$work/wrapped")" = "$long" ]

# UTF-8 input must retain character and display widths.
tmux -L "$socket" send-keys -l -t test "printf '%s' 'è界' > '$work/unicode'"
check_gif
tmux -L "$socket" send-keys -t test Enter
wait_file "$work/unicode"
[ "$(cat "$work/unicode")" = 'è界' ]
# Secondary prompts must use their own insertion column.
tmux -L "$socket" send-keys -l -t test "printf '%s' 'first"
tmux -L "$socket" send-keys -t test Enter
check_gif
tmux -L "$socket" send-keys -l -t test "second' > '$work/multiline'"
tmux -L "$socket" send-keys -t test Enter
wait_file "$work/multiline"
printf 'first\nsecond' > "$work/multiline-expected"
cmp "$work/multiline" "$work/multiline-expected"
# Normal command output may scroll the terminal; the next prompt stays aligned.
tmux -L "$socket" send-keys -t test "for n in {1..50}; do echo output-\$n; done; cd /; printf scrolled > '$work/scrolled'" Enter
wait_file "$work/scrolled"
check_gif
# Ctrl+C in ZLE stops animation and cancels only the edit buffer.
tmux -L "$socket" send-keys -l -t test 'echo must-not-run'
tmux -L "$socket" send-keys -t test C-c
sleep 0.2
tmux -L "$socket" send-keys -t test "printf cancelled > '$work/cancelled'" Enter
wait_file "$work/cancelled"
tmux -L "$socket" capture-pane -p -t test > "$work/cancel-screen"
perl -CSDA -ne 'die "GIF still visible after Ctrl+C\n" if /[\x{2500}-\x{259f}]/;' "$work/cancel-screen"
tmux -L "$socket" send-keys -t test '67' Enter
check_gif
# Ctrl+C still interrupts foreground commands normally.
tmux -L "$socket" send-keys -t test 'sleep 30' Enter
sleep 0.2
tmux -L "$socket" send-keys -t test C-c
sleep 0.2
tmux -L "$socket" send-keys -t test "printf interrupted > '$work/interrupted'" Enter
wait_file "$work/interrupted"
tmux -L "$socket" capture-pane -p -t test > "$work/interrupted-screen"
perl -CSDA -ne 'die "GIF returned without 67 after Ctrl+C\n" if /[\x{2500}-\x{259f}]/;' "$work/interrupted-screen"
tmux -L "$socket" send-keys -t test '67' Enter
check_gif
printf '%s\n' 'PASS: stop/restart, UTF-8, multiline prompts, output scrolling and Ctrl+C'
# Finish the session; its renderer and temporary startup directory must vanish.
zshpid=$(tmux -L "$socket" display-message -p -t test '#{pane_pid}')
tmux -L "$socket" send-keys -t test "print -r -- \$ZDOTDIR > '$work/config'; print -r -- \$\$ > '$work/zshpid'" Enter
wait_file "$work/config"
sleep 0.1
children=$(pgrep -P "$(cat "$work/zshpid")" chafa || :)
tmux -L "$socket" send-keys -t test exit Enter
wait_file "$work/returned"
[ ! -d "$(cat "$work/config")" ]
for child in $children; do
    tries=0
    while kill -0 "$child" 2>/dev/null; do
        tries=$((tries+1)); [ "$tries" -lt 20 ] || { printf 'Renderer leaked: %s\n' "$child"; exit 1; }; sleep 0.05
    done
done
printf '%s\n' 'PASS: exit restores the original shell and removes renderer/configuration'
printf 'Evidence: %s\n' "$work"
