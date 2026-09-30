# Decode the truecolor SGR subset emitted by Chafa with --colors full.
# Input: one ANSI line; output: REPLY (glyphs), reply (relative color spans).
# The caller owns _67_decode_fg/bg/inverse as dynamically scoped locals:
# color state carries across lines within a frame, then resets for the next.

_67_decode_line() {
    local text=$1 glyphs='' style='' color='' character='' previous_style=''
    local foreground=$_67_decode_fg background=$_67_decode_bg
    local csi_pattern=$'^\e\\[([0-9;?]*)([A-Za-z])'
    local -a parameters
    local -i index position=0 span_start=0 inverse=$_67_decode_inverse
    reply=()
    while [[ -n $text ]]; do
        if [[ $text =~ $csi_pattern ]]; then
            text=${text[${#MATCH}+1,-1]}
            if [[ ${match[2]} == m ]]; then
                parameters=("${(@s:;:)match[1]}")
                for ((index=1; index<=${#parameters}; index++)); do
                    case ${parameters[index]} in
                        0|'')
                            foreground=''
                            background=''
                            inverse=0
                            ;;
                        7) inverse=1 ;;
                        27) inverse=0 ;;
                        39) foreground='' ;;
                        49) background='' ;;
                        38|48)
                            if [[ ${parameters[index+1]} == 2 ]] && (( index+4 <= ${#parameters} )); then
                                printf -v color '#%02x%02x%02x' \
                                    "${parameters[index+2]}" "${parameters[index+3]}" "${parameters[index+4]}"
                                if [[ ${parameters[index]} == 38 ]]; then
                                    foreground=$color
                                else
                                    background=$color
                                fi
                                ((index+=4))
                            fi
                            ;;
                    esac
                done
            fi
            continue
        fi
        # Cursor controls such as ESC D are not image glyphs.
        if [[ ${text[1]} == $'\e' ]]; then
            text=${text[3,-1]}
            continue
        fi
        character=${text[1]}
        text=${text[2,-1]}
        glyphs+=$character
        style=''
        [[ -z $foreground ]] || style="fg=$foreground"
        [[ -z $background ]] || style+="${style:+,}bg=$background"
        (( ! inverse )) || style+="${style:+,}standout"
        # Adjacent cells with the same colors need just one highlight region.
        if [[ $style != $previous_style ]]; then
            [[ -z $previous_style ]] || reply+=("$span_start $position $previous_style")
            previous_style=$style
            span_start=$position
        fi
        ((position++))
    done
    [[ -z $previous_style ]] || reply+=("$span_start $position $previous_style")
    REPLY=$glyphs
    _67_decode_fg=$foreground
    _67_decode_bg=$background
    _67_decode_inverse=$inverse
}
