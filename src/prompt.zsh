# Entry point for 67's private interactive Zsh session.
# Keep user startup files untouched; all integration lives in this session.
setopt multibyte interactivecomments
unsetopt beep
PROMPT=''
PROMPT2=''
RPROMPT=''
HISTSIZE=1000
bindkey -e
zmodload zsh/system

typeset -g _67_prompt='%n@%m:%~%# ' _67_prompt2='> '
typeset -gi _67_height=8 _67_width=48

# Resolve modules from this file, independently of cwd and ZDOTDIR.
# Load definitions before editor.zsh registers widgets and signal handlers.
typeset -g _67_module_dir=${${(%):-%x}:A:h}/prompt
source "$_67_module_dir/ansi.zsh"
source "$_67_module_dir/frames.zsh"
source "$_67_module_dir/renderer.zsh"
source "$_67_module_dir/editor.zsh"
unset _67_module_dir
