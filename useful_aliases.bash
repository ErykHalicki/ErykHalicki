# useful_aliases.bash
# Portable shell aliases/functions for Ubuntu or macOS.
# This repo is expected to live at ~/Documents/ErykHalicki on every machine.
# Source it from ~/.zshrc or ~/.bashrc:
#   [ -f ~/Documents/ErykHalicki/useful_aliases.bash ] && . ~/Documents/ErykHalicki/useful_aliases.bash

# --- navigation ---
alias s=source
alias school="cd ~/Documents/School/"
alias honours="cd ~/Documents/School/UBC/year4/bachelor-thesis"
alias proj="cd ~/Documents/projects"
alias projects="cd ~/Documents/projects"

# --- ssh (define `pc` / `zima` Host blocks in ~/.ssh/config; see setup.md) ---
alias pc='ssh pc'
alias zima='ssh zima; printf "\e[?1000l\e[?1006l\e[?1015l"'

# --- editor ---
alias nvim-clean="command nvim"
nvim() {
  command nvim -c Start "$@"
}
alias work="nvim -c Start"

# --- neofetch with custom ascii art (falls back to plain neofetch) ---
alias neofetch='command neofetch $([ -f ~/Documents/ErykHalicki/walle-ascii-art.txt ] && echo "--ascii ~/Documents/ErykHalicki/walle-ascii-art.txt --ascii_colors 1 4 3 2 5 6")'
