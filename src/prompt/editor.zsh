# ZLE owns all visible text. Sprite glyphs stay in PREDISPLAY so they can
# never enter BUFFER or an accepted command. Only redraw starts a renderer;
# finishing a line stops it while retaining the cached frame for the next.
typeset -gi _67_enabled=1

_67_finish() {
    # Clear spans before removing their display: otherwise ZLE can apply the
    # sprite's colors to the command it is about to accept.
    region_highlight=()
    PREDISPLAY=''
    _67_stop_renderer
}

_67_redraw() {
    local prompt_text="${(%)_67_prompt}"
    [[ $CONTEXT != cont ]] || prompt_text="${(%)_67_prompt2}"
    region_highlight=()
    PREDISPLAY=$prompt_text
    (( _67_enabled )) || return 0
    # A hidden sprite must not keep rendering. Resizing back starts it again.
    if (( COLUMNS < _67_width || LINES < _67_height + 2 )); then
        (( _67_fd < 0 )) || _67_finish
        PREDISPLAY=$prompt_text
        return 0
    fi
    (( _67_fd >= 0 )) || _67_start_renderer
    [[ -n $_67_sprite ]] || return 0
    PREDISPLAY=$_67_sprite$prompt_text
    region_highlight=("${_67_highlights[@]}")
}

_67_interrupt() {
    _67_enabled=0
    region_highlight=()
    PREDISPLAY=''
    # Erase the sprite before waiting for the renderer to shut down.
    zle -R
    _67_finish
    zle .send-break
}

67() {
    case ${1:-} in
        '') _67_enabled=1 ;;
        --stop)
            _67_enabled=0
            _67_finish
            ;;
        --help|-h) command "$SIXTYSEVEN_BIN" --help ;;
        *)
            print -u2 -- 'Uso: 67 [--stop]'
            return 2
            ;;
    esac
}

_67_resize() {
    local -a size
    # Zsh can dispatch SIGWINCH before updating COLUMNS/LINES. Read the real
    # dimensions once per resize, never on animation frames or keypresses.
    size=( $(command stty size 2>/dev/null < /dev/tty) )
    if (( ${#size} == 2 )); then
        LINES=${size[1]}
        COLUMNS=${size[2]}
    fi
    region_highlight=()
    PREDISPLAY=''
    zle .clear-screen
    _67_redraw
    # Reflow can move the display origin above the viewport. When bringing
    # back a hidden sprite, rebuild the screen at a known visible origin.
    zle -R
}

TRAPWINCH() {
    # Queue a widget outside the trap: Zsh documents that removing a watched
    # descriptor inside a signal trap can corrupt the event loop.
    if zle; then
        zle -U $'\e[67~'
    fi
    return 0
}

TRAPINT() {
    # Terminals normally deliver Ctrl+C as SIGINT before a key binding sees it.
    _67_enabled=0
    if zle; then
        zle _67_interrupt
    else
        _67_finish
    fi
    return 130
}

precmd() {
    # Also cover Ctrl+C delivered to a foreground command's process group.
    if (( $? == 130 )); then _67_enabled=0; fi
}

TRAPEXIT() { _67_finish; }

zle -N _67_read_frame_line
zle -N _67_resize
zle -N zle-line-init _67_redraw
zle -N zle-line-finish _67_finish
zle -N zle-line-pre-redraw _67_redraw
zle -N _67_interrupt
bindkey '^C' _67_interrupt
bindkey $'\e[67~' _67_resize
