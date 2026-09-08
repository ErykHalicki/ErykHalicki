# Setup

Personal config for a fresh Ubuntu or macOS machine. This repo is expected to
live at `~/Documents/ErykHalicki` on every machine so paths resolve the same.

## 1. Clone

```bash
mkdir -p ~/Documents
git clone https://github.com/ErykHalicki/ErykHalicki.git ~/Documents/ErykHalicki
```

## 2. Shell aliases

Add this to `~/.zshrc` (macOS) or `~/.bashrc` (Ubuntu):

```bash
[ -f ~/Documents/ErykHalicki/useful_aliases.bash ] && . ~/Documents/ErykHalicki/useful_aliases.bash
```

Then `source ~/.zshrc` (or open a new terminal).

### Optional env overrides

The ssh aliases default to known hosts but can be overridden without editing
the file:

```bash
export PC_HOST=user@host
export ZIMA_HOST=user@host
```

## 3. Neovim config

```bash
mkdir -p ~/.config/nvim
ln -s ~/Documents/ErykHalicki/init.lua ~/.config/nvim/init.lua
# or use init.vim instead
```

## 4. Tools referenced by the aliases

Install as needed:

- `neovim`
- `neofetch` (uses `walle-ascii-art.txt` from this repo)
- `openssh-client`

macOS: `brew install neovim neofetch`
Ubuntu: `sudo apt install neovim neofetch`

## Files

| File | Purpose |
|------|---------|
| `useful_aliases.bash` | Portable shell aliases/functions |
| `init.lua` / `init.vim` | Neovim config |
| `walle-ascii-art.txt` | neofetch ascii art |
| `clang-format` | C/C++ formatting rules |
