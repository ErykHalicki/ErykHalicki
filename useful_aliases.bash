# useful_aliases.bash
# Portable shell aliases/functions for Ubuntu or macOS.
# This repo is expected to live at ~/Documents/ErykHalicki on every machine.
# Source it from ~/.zshrc or ~/.bashrc:
#   [ -f ~/Documents/ErykHalicki/useful_aliases.bash ] && . ~/Documents/ErykHalicki/useful_aliases.bash

# --- navigation ---
alias s=source
_first_dir() { for d; do [ -d "$d" ] && { printf '%s\n' "$d"; return; }; done; }
alias school='cd "$(_first_dir ~/School ~/Documents/School)"'
alias thesis='cd "$(_first_dir ~/School/thesis ~/Documents/School/UBC/year4/thesis)"'
alias honours=thesis
alias capstone='cd "$(_first_dir ~/School/capstone ~/Documents/School/UBC/year4/capstone)"'
alias proj="cd ~/Documents/projects"
alias projects="cd ~/Documents/projects"

# --- ssh (define `pc` / `zima` Host blocks in ~/.ssh/config; see setup.md) ---
alias pc='ssh pc'
alias zima='ssh zima; printf "\e[?1000l\e[?1006l\e[?1015l"'

# --- editor ---
alias nvim-clean="command nvim"
nvim() {
  if [ -n "$NVIM" ]; then
    echo "nvim: already inside an nvim terminal, not starting a nested one (use nvim-clean to force it)" >&2
    return 1
  fi
  command nvim -c Start "$@"
}
alias work="nvim"

# --- neofetch with custom ascii art (falls back to plain neofetch) ---
unalias neofetch 2>/dev/null
neofetch() {
    local art="$HOME/Documents/ErykHalicki/walle-ascii-art.txt"
    if [ $# -eq 0 ] && [ -z "$NVIM" ] && [ -f "$HOME/sockeye_swim.py" ] && (( RANDOM % 2 )); then
        python3 "$HOME/sockeye_swim.py" --fetch --color
    elif [ -f "$art" ]; then
        command neofetch --ascii "$art" --ascii_colors 1 4 3 2 5 6 "$@"
    else
        command neofetch "$@"
    fi
}
