#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias l='ls -lFha --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

if uwsm check may-start > /dev/null 2>&1; then
	exec uwsm start hyprland.desktop
fi

function open () {
  xdg-open "$@">/dev/null 2>&1
}

export EDITOR=vim
source /usr/share/git/completion/git-completion.bash 
. "$HOME/.local/share/../bin/env"
