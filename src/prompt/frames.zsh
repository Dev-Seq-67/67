# Cache keys are complete ANSI frames; values are glyphs and ZLE spans.
# A P-prefixed span is relative to PREDISPLAY, never to the user's BUFFER.
typeset -gi _67_cache_limit=32
typeset -ga _67_pending=() _67_highlights=()
typeset -g _67_sprite=''
typeset -gA _67_cached_display=() _67_cached_highlights=()

_67_publish_frame() {
    local line REPLY span key display='' _67_decode_fg='' _67_decode_bg=''
    local -a reply parts
    local -i offset _67_decode_inverse=0
    # Cache complete frames, including absolute highlight offsets. Input
    # always follows the sprite, so these offsets never depend on BUFFER.
    key="${(F)_67_pending}"
    if (( ! ${+_67_cached_display[$key]} )); then
        # Keep memory bounded even if the asset has many different frames.
        if (( ${#_67_cached_display} >= _67_cache_limit )); then
            _67_cached_display=()
            _67_cached_highlights=()
        fi
        _67_highlights=()
        for line in "${_67_pending[@]}"; do
            offset=${#display}
            _67_decode_line "$line"
            display+=$REPLY$'\n'
            for span in "${reply[@]}"; do
                parts=( ${=span} )
                _67_highlights+=("P$((offset + parts[1])) $((offset + parts[2])) ${parts[3]}")
            done
        done
        _67_cached_display[$key]=$display
        _67_cached_highlights[$key]="${(F)_67_highlights}"
    fi
    _67_sprite=${_67_cached_display[$key]}
    _67_highlights=("${(@f)_67_cached_highlights[$key]}")
    _67_pending=()
    _67_redraw
    zle -R
}
