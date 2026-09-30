#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
program=${PROGRAM:-$root/src/67}
label=${1:-current}
seconds=${2:-${SECONDS_PER_PHASE:-8}}
work=$(mktemp -d /tmp/67-resources.XXXXXX)
socket=67-resources-$$
export TERM=xterm-256color LANG=C.UTF-8
cleanup() { tmux -L "$socket" kill-server 2>/dev/null || :; }
trap cleanup 0
wait_file() {
    attempts=0
    until [ -s "$1" ]; do
        attempts=$((attempts+1))
        [ "$attempts" -lt 100 ] || { printf 'Timeout: %s\n' "$1" >&2; exit 1; }
        sleep 0.05
    done
}
tmux -L "$socket" -f /dev/null new-session -d -s test -x 160 -y 24 /bin/bash --noprofile --norc
tmux -L "$socket" send-keys -t test "cd /tmp; '$program'; printf returned > '$work/returned'" Enter
sleep 1
tmux -L "$socket" send-keys -t test "print -r -- \$\$ > '$work/pid'" Enter
wait_file "$work/pid"
pid=$(cat "$work/pid")
sleep 1
tmux -L "$socket" capture-pane -p -e -t test > "$work/active-screen"
tmux -L "$socket" display-message -p -t test '#{cursor_x} #{cursor_y}' > "$work/active-coords"
perl "$root/tests/layout.pl" "$work/active-screen" "$work/active-coords"
for frame in 1 2 3 4 5; do
    tmux -L "$socket" capture-pane -p -e -t test > "$work/frame-$frame"
    sleep 0.15
done
[ "$(sha256sum "$work"/frame-* | cut -d ' ' -f1 | sort -u | wc -l)" -ge 2 ]
perl "$root/tests/resources.pl" "$pid" "$seconds" "$label:animated" | tee "$work/animated.json"
perl -MJSON::PP -e '
    open my $f,"<",$ARGV[0] or die; my $r=decode_json(<$f>);
    die "Animated CPU exceeds budget\n" if $r->{cpu_percent_one_core} > ($ENV{MAX_CPU_PERCENT} // 5);
    die "Animated RSS exceeds budget\n" if $r->{peak_rss_kib} > ($ENV{MAX_RSS_KIB} // 65536);
    die "Too many threads or processes\n" if $r->{peak_threads} > 2 || $r->{peak_processes} > 2;
' "$work/animated.json"
start=$(date +%s%N)
tmux -L "$socket" send-keys -l -t test "printf responsive > '$work/latency'"
tmux -L "$socket" send-keys -t test Enter
wait_file "$work/latency"
latency_ms=$(( ($(date +%s%N)-start)/1000000 ))
[ "$latency_ms" -lt 1000 ]
printf 'PASS: command input and execution latency %s ms\n' "$latency_ms" | tee "$work/latency.txt"
tmux -L "$socket" resize-window -t test -x 40 -y 24
attempts=0
while pgrep -P "$pid" chafa >/dev/null; do
    attempts=$((attempts+1)); [ "$attempts" -lt 30 ] || { printf '%s\n' 'Hidden renderer did not exit'; exit 1; }
    sleep 0.1
done
sleep 0.1
perl "$root/tests/resources.pl" "$pid" "$seconds" "$label:narrow" | tee "$work/narrow.json"
perl -MJSON::PP -e '
    open my $f,"<",$ARGV[0] or die; my $r=decode_json(<$f>);
    die "Hidden sprite still renders\n" if $r->{peak_processes} != 1;
    die "Hidden sprite consumes CPU\n" if $r->{cpu_percent_one_core} > 1;
' "$work/narrow.json"
tmux -L "$socket" resize-window -t test -x 160 -y 24
sleep 0.4
attempts=0
while :; do
    tmux -L "$socket" capture-pane -p -e -t test > "$work/restored-screen"
    tmux -L "$socket" display-message -p -t test '#{cursor_x} #{cursor_y}' > "$work/restored-coords"
    if perl "$root/tests/layout.pl" "$work/restored-screen" "$work/restored-coords" > "$work/restored-check" 2>&1; then break; fi
    attempts=$((attempts+1)); [ "$attempts" -lt 30 ] || { cat "$work/restored-check"; exit 1; }
    sleep 0.1
done
cat "$work/restored-check"
tmux -L "$socket" send-keys -t test C-c
sleep 0.2
tmux -L "$socket" capture-pane -p -t test > "$work/stopped-screen"
perl -CSDA -ne 'die "Sprite remains after Ctrl+C following resize\n" if /[\x{2500}-\x{259f}]/;' "$work/stopped-screen"
perl "$root/tests/resources.pl" "$pid" "$seconds" "$label:stopped" | tee "$work/stopped.json"
perl -MJSON::PP -e '
    open my $f,"<",$ARGV[0] or die; my $r=decode_json(<$f>);
    die "Renderer still alive after Ctrl+C\n" if $r->{peak_processes} != 1;
    die "CPU still busy after Ctrl+C\n" if $r->{cpu_percent_one_core} > 1;
' "$work/stopped.json"
# Repeated restart/stop must not grow the descriptor set or leave renderers.
tmux -L "$socket" send-keys -t test "print -r -- \$ZDOTDIR > '$work/config'" Enter
wait_file "$work/config"
fds_before=$(find "/proc/$pid/fd" -mindepth 1 -maxdepth 1 | wc -l)
rss_before=$(awk '/^VmRSS:/ {print $2}' "/proc/$pid/status")
for n in 1 2 3 4 5; do
    tmux -L "$socket" send-keys -t test '67' Enter
    sleep 0.4
    tmux -L "$socket" send-keys -t test C-c
    sleep 0.2
done
fds_after=$(find "/proc/$pid/fd" -mindepth 1 -maxdepth 1 | wc -l)
rss_after=$(awk '/^VmRSS:/ {print $2}' "/proc/$pid/status")
[ "$fds_before" -eq "$fds_after" ]
[ "$((rss_after-rss_before))" -le 2048 ]
[ -z "$(pgrep -P "$pid" chafa || :)" ]
tmux -L "$socket" send-keys -t test exit Enter
wait_file "$work/returned"
[ ! -d "$(cat "$work/config")" ]
[ ! -d "/proc/$pid" ]
printf '%s\n' 'PASS: idle CPU after Ctrl+C, no descriptor/process leaks, exit cleanup'
printf 'Evidence: %s\n' "$work"
