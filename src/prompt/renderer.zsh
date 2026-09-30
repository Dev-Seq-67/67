# Own exactly one process substitution and its output descriptor.
# _67_fd == -1 means stopped; _67_pid identifies only our Chafa process.
typeset -gi _67_fd=-1 _67_pid=0
typeset -ga _67_chafa_args=(--format symbols --colors full --animate on
    --duration inf --symbols block+space --size "${_67_width}x${_67_height}"
    --view-size "${_67_width}x${_67_height}" --margin-bottom 0 --optimize 1
    --threads 1 --work 1)
# Recent Chafa releases probe the terminal; keyboard input belongs to ZLE.
if command chafa --help 2>/dev/null | command grep -q -- '--probe'; then
    _67_chafa_args+=(--probe off)
fi

_67_start_renderer() {
    # $! belongs to the user's last background job. Get the renderer's actual
    # PID from its own process instead, preserving ordinary shell job control.
    exec {_67_fd}< <(
        print -r -- $sysparams[pid]
        exec chafa "${_67_chafa_args[@]}" "$SIXTYSEVEN_GIF" < /dev/null
    )
    IFS= read -r -u $_67_fd _67_pid
    zle -F -w $_67_fd _67_read_frame_line
}

_67_stop_renderer() {
    local discarded
    if (( _67_fd >= 0 )); then
        zle -F $_67_fd 2>/dev/null
    fi
    if (( _67_pid > 0 )); then
        kill -TERM $_67_pid 2>/dev/null
        _67_pid=0
    fi
    if (( _67_fd >= 0 )); then
        # Process substitutions are not jobs that Zsh's wait can reap.
        # EOF confirms the renderer has closed its output before we return.
        while IFS= read -r -t 1 -u $_67_fd discarded; do :; done
        exec {_67_fd}<&-
        _67_fd=-1
    fi
    _67_pending=()
    return 0
}

_67_read_frame_line() {
    local line
    # Ignore a queued callback for a descriptor already closed on resize/stop.
    [[ $1 == $_67_fd ]] || return 0
    if [[ -n ${2:-} ]] || ! IFS= read -r -u "$1" line; then
        _67_enabled=0
        _67_finish
        zle -R
        return
    fi
    _67_pending+=("$line")
    if (( ${#_67_pending} == _67_height )); then
        _67_publish_frame
    fi
}
