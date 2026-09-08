# useful_aliases.bash
# Portable shell aliases/functions for Ubuntu or macOS.
# This repo is expected to live at ~/Documents/ErykHalicki on every machine.
# Source it from ~/.zshrc or ~/.bashrc:
#   [ -f ~/Documents/ErykHalicki/useful_aliases.bash ] && . ~/Documents/ErykHalicki/useful_aliases.bash

# --- navigation ---
alias s=source
alias school="cd ~/Documents/School/"
alias honours="cd ~/Documents/School/UBC/year4/bachelor-thesis"
alias proj="cd ~/Documents/projects/current"
alias projects="cd ~/Documents/projects/current"

# --- ssh (set host/user via env vars, no secrets committed) ---
# export PC_HOST=user@host   (optionally use ~/.ssh/config + key auth instead)
alias pc='ssh "${PC_HOST:-eryk@100.102.68.50}"'
alias zima='ssh "${ZIMA_HOST:-zima@zima-brain.local}"; printf "\e[?1000l\e[?1006l\e[?1015l"'

# --- editor ---
alias nvim-clean="command nvim"
nvim() {
  command nvim -c Start "$@"
}
alias work="nvim -c Start"

# --- neofetch with custom ascii art (falls back to plain neofetch) ---
alias neofetch='command neofetch $([ -f ~/Documents/ErykHalicki/walle-ascii-art.txt ] && echo "--ascii ~/Documents/ErykHalicki/walle-ascii-art.txt --ascii_colors 1 4 3 2 5 6")'
