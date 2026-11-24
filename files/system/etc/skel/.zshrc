# History
HISTSIZE=100000
SAVEHIST=1000000
HISTFILE=~/.zsh_history
setopt inc_append_history
setopt share_history
setopt hist_ignore_dups
setopt hist_ignore_all_dups

# Alias
alias ls='ls --color=auto'
alias grep='grep --color=auto'

# Env
export EDITOR=vim
export WORDCHARS='*?_.[]~-=&;!#$%^(){}<>'

# Options
setopt auto_cd
setopt auto_pushd
setopt pushd_ignore_dups
setopt no_flow_control
setopt extended_glob
setopt menu_complete
setopt nonomatch
setopt correct
setopt list_packed
setopt magic_equal_subst

# Antidote is shared by the host and distroboxes that use this home.
# Load its completion paths before compinit.
_hyprtomic_antidote=
if [[ -r "$HOME/.zsh_plugins.txt" ]]; then
    for _antidote in "${ANTIDOTE_ZSH_FILE:-$HOME/.antidote/antidote.zsh}" \
        "${XDG_DATA_HOME:-$HOME/.local/share}/antidote/antidote.zsh"; do
        [[ -r "$_antidote" ]] || continue
        if source "$_antidote" && antidote load "$HOME/.zsh_plugins.txt"; then
            _hyprtomic_antidote=1
            break
        fi
    done
fi
unset _antidote

# Hosts and distroboxes can have different completion functions even with
# the same zsh version. Do not reuse each other's completion caches.
_completion_env=host
[[ -n ${CONTAINER_ID:-} ]] && _completion_env="distrobox-$CONTAINER_ID"
_completion_cache="${XDG_CACHE_HOME:-$HOME/.cache}/hyprtomic/zsh/$_completion_env/$ZSH_VERSION"
autoload -Uz compinit
if mkdir -p -- "$_completion_cache"; then
    compinit -d "$_completion_cache/.zcompdump"
    zstyle ':completion:*' cache-path "$_completion_cache"
else
    compinit -D
fi
unset _completion_env _completion_cache
zstyle ':completion:*' menu select
zstyle ':completion::complete:*' use-cache true
zstyle ':completion:*' list-colors "${LS_COLORS}"
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*:manuals' separate-sections true

# VCS info
autoload -Uz vcs_info
setopt prompt_subst
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' stagedstr "%F{magenta}!"
zstyle ':vcs_info:git:*' unstagedstr "%F{yellow}+"
zstyle ':vcs_info:*' formats "%F{cyan}%c%u[%b]%f"
zstyle ':vcs_info:*' actionformats '[%b|%a]'
precmd () { vcs_info }
PROMPT='%F{magenta}%B%n%b%f@%F{blue}%U%m%u%f:%F{green}%1~%f%F{cyan}$vcs_info_msg_0_%f%F{white}$%f '

# Key bindings
bindkey '^[[H'  beginning-of-line
bindkey '^[[F'  end-of-line
bindkey '^[[1~' beginning-of-line
bindkey '^[[4~' end-of-line
bindkey '^[[3~' delete-char
bindkey '^[[2~' overwrite-mode
bindkey '^[[5~' history-search-backward
bindkey '^[[6~' history-search-forward
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

# terminfo
if [[ "${terminfo[kdch1]}" != "" ]]; then bindkey "${terminfo[kdch1]}" delete-char; fi
if [[ "${terminfo[khome]}" != "" ]]; then bindkey "${terminfo[khome]}" beginning-of-line; fi
if [[ "${terminfo[kend]}"  != "" ]]; then bindkey "${terminfo[kend]}"  end-of-line; fi

# Local bin (sunshine-session etc.)
export PATH="$HOME/.local/bin:$PATH"

# Extra shell snippets (e.g. generated terminal colors)
for f in ~/.config/zshrc.d/*.zsh(N) ~/.config/zshrc.d/*.sh(N); do
    source "$f"
done

# Bitwarden SSH agent. Native builds use the home-directory socket; the
# Flatpak path is kept as a fallback.
if [[ -S "$HOME/.bitwarden-ssh-agent.sock" ]]; then
    export SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock"
elif [[ -S "$HOME/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock" ]]; then
    export SSH_AUTH_SOCK="$HOME/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock"
fi

# Keep the image's Fedora plugins available without an Antidote install.
# Syntax highlighting deliberately runs after compinit and user snippets.
if [[ -z $_hyprtomic_antidote ]]; then
    [[ -r /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
        source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    [[ -r /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
        source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi
unset _hyprtomic_antidote
