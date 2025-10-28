#!/usr/bin/env zsh
# vim:syntax=zsh
# vim:filetype=zsh

# make fzf ctrl-r behave like zaw, via https://github.com/fsouza/dotfiles/blob/main/extra/fzf
function _rebind_ctrl-r {
	function fzf-history-widget {
		local selected num
		setopt localoptions noglobsubst noposixbuiltins pipefail no_aliases 2> /dev/null
		selected=( $(fc -rl 1 | perl -ne 'print if !$seen{($_ =~ s/^\s*[0-9]+\s+//r)}++' |
			FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} ${FZF_DEFAULT_OPTS} -n2..,.. --tiebreak=index --bind=ctrl-r:toggle-sort --expect=ctrl-e $FZF_CTRL_R_OPTS --query=${(qqq)LBUFFER} +m" $(__fzfcmd)) )
		local ret=$?
		if [ -n "${selected}" ]; then
			local accept=0
			if [[ $selected[1] == ctrl-e ]]; then
				accept=1
				shift selected
			fi
			num=$selected[1]
			if [ -n "${num}" ]; then
				zle vi-fetch-history -n $num
				[[ $accept = 0 ]] && zle accept-line
			fi
		fi
		zle reset-prompt
		return $ret
	}
	zle     -N   fzf-history-widget
	bindkey '^R' fzf-history-widget
}

function _setup_fzf {
	# ensure fzf completion and key-bindings is configured.
	if [[ -v HOMEBREW_PREFIX ]] && [ -d ${HOMEBREW_PREFIX}/opt/fzf ]; then
		[[ $- == *i* ]] && source ${HOMEBREW_PREFIX}/opt/fzf/shell/completion.zsh 2> /dev/null

		# very opinionated FZF style opts.
		export FZF_DEFAULT_OPTS="
			--bind=ctrl-e:accept
			--cycle
			--height=40% --layout=reverse --border=none --info=hidden --margin=0% --marker='*' --history-size=${HISTSIZE}
			--color=dark
			--color=fg:-1,bg:-1,hl:#c678dd,fg+:#ffffff,bg+:#252931,hl+:#d858fe
			--color=info:#98c379,prompt:#61afef,pointer:#be5046,marker:#e5c07b,spinner:#61afef,header:#61afef
		"
		export FZF_DEFAULT_COMMAND="fd --type f --hidden -E '.git' -E '.hg'"

		source ${HOMEBREW_PREFIX}/opt/fzf/shell/key-bindings.zsh
		_rebind_ctrl-r
	fi
}

if command -v fzf &>/dev/null; then
	_setup_fzf
fi