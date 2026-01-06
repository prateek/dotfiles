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

# Ctrl-T: Make fzf's file widget "path aware".
#
# The upstream fzf ctrl-t widget always appends selections to the end of LBUFFER.
# Here we instead:
# - parse the token under the cursor (LBUFFER+RBUFFER, whitespace-delimited)
# - if it looks like a path prefix (e.g. `src/pa`), scope candidates to `src/**`
#   and seed fzf's query with `pa`
# - replace the token under the cursor with the selected path(s)
#
# TODO: upstream this to fzf's `shell/key-bindings.zsh`?
function _rebind_ctrl-t {
	function __fzf_file_select {
		setopt localoptions pipefail no_aliases 2> /dev/null
		local fzf_command="$1"
		local query="$2"
		shift 2

		local -a fzf_args
		if [[ -n "$query" ]]; then
			fzf_args+=(--query="$query")
		fi
		fzf_args+=("$@")

		local item
		FZF_DEFAULT_COMMAND="$fzf_command" \
		FZF_DEFAULT_OPTS=$(__fzf_defaults "--reverse --walker=file,dir,follow,hidden --scheme=path" "${FZF_CTRL_T_OPTS-} -m") \
		FZF_DEFAULT_OPTS_FILE='' $(__fzfcmd) "${fzf_args[@]}" < /dev/tty | while read -r item; do
			echo -n -E "${(q)item} "
		done
		local ret=$?
		echo
		return $ret
	}

	function fzf-file-widget {
		setopt localoptions pipefail no_aliases 2> /dev/null

		# Best-effort: treat the "current token" as whitespace-delimited, and
		# use the (dir, basename) parts to scope + seed fzf.
		local lbuf="$LBUFFER"
		local rbuf="$RBUFFER"

		local ltok="${lbuf##*[[:space:]]}"
		local lpref_len=$(( ${#lbuf} - ${#ltok} ))
		local lpref=""
		if (( lpref_len > 0 )); then
			lpref="${lbuf[1,$lpref_len]}"
		fi

		local rtok="${rbuf%%[[:space:]]*}"
		local rsuf_start=$(( ${#rtok} + 1 ))
		local rsuf=""
		if (( rsuf_start <= ${#rbuf} )); then
			rsuf="${rbuf[$rsuf_start,-1]}"
		fi

		local token="${ltok}${rtok}"

		# Support common --flag=PATH forms by only treating the RHS as a path.
		local token_prefix=""
		local path_token="$token"
		if [[ "$token" == *'='* ]]; then
			local after_eq="${token##*=}"
			if [[ "$after_eq" == */* || "$after_eq" == .* || "$after_eq" == ~* ]]; then
				token_prefix="${token[1,$(( ${#token} - ${#after_eq} ))]}"
				path_token="$after_eq"
			fi
		fi

		local dir_part="" query="$path_token"
		if [[ "$path_token" == */* ]]; then
			dir_part="${path_token%/*}/"
			query="${path_token##*/}"

			local dir_check="${dir_part/#\~/$HOME}"
			if [[ ! -d "$dir_check" ]]; then
				dir_part=""
				query="$path_token"
			fi
		fi

		local fzf_command
		if [[ -n "$dir_part" ]]; then
			fzf_command="print -rl -- ${(q)dir_part}**/*(.Om) 2>/dev/null"
		else
			fzf_command="${FZF_CTRL_T_COMMAND:-}"
		fi

		local insert="$(__fzf_file_select "$fzf_command" "$query")"
		local ret=$?
		if (( ret != 0 )); then
			LBUFFER="$lbuf"
			RBUFFER="$rbuf"
			zle reset-prompt
			return $ret
		fi

		LBUFFER="${lpref}${token_prefix}${insert}"
		RBUFFER="$rsuf"
		zle reset-prompt
		return 0
	}

	zle     -N            fzf-file-widget
	bindkey -M emacs '^T' fzf-file-widget
	bindkey -M vicmd '^T' fzf-file-widget
	bindkey -M viins '^T' fzf-file-widget
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
		# Keep ctrl-t and alt-c lists in newest-first order
		export FZF_CTRL_T_COMMAND="print -rl -- **/*(.Om) 2>/dev/null"   # files, newest→oldest
		export FZF_ALT_C_COMMAND="print -rl -- **/*(/Om) 2>/dev/null"    # dirs, newest→oldest
		# Default file source (used by some widgets); order doesn’t matter here
		export FZF_DEFAULT_COMMAND="fd --type f --hidden -E '.git' -E '.hg'"

		source ${HOMEBREW_PREFIX}/opt/fzf/shell/key-bindings.zsh
		_rebind_ctrl-r
		_rebind_ctrl-t
	fi
}

if command -v fzf &>/dev/null; then
	_setup_fzf
    # Ensure fzf-tab owns <Tab> binding last, after fzf's own completion
    # is loaded. This makes fzf-tab use zsh compsys results (and thus
    # respect zstyles like file-sort) instead of fzf's completion widget.
    if typeset -f enable-fzf-tab >/dev/null; then
        enable-fzf-tab
    fi
fi
