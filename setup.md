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

## 3. SSH hosts

The `pc` / `zima` aliases run `ssh pc` / `ssh zima`, so those names need
`Host` blocks in `~/.ssh/config` (nothing host-specific is committed):

```
Host zima
    HostName zima-brain.local
    User zima
    IdentityFile ~/.ssh/id_ed25519

Host pc
    HostName <pc-hostname-or-ip>
    User <user>
    IdentityFile ~/.ssh/id_ed25519
```

Then `chmod 600 ~/.ssh/config`.

Set up key auth so the aliases don't prompt for a password:

```bash
# generate a key if this machine has none
ls ~/.ssh/id_ed25519 || ssh-keygen -t ed25519

# trust the host key, then install your public key
ssh-keyscan -H zima-brain.local >> ~/.ssh/known_hosts
ssh-copy-id zima
```

If `ssh-copy-id` fails with `ssh_askpass: ... No such file or directory`,
unset the GUI askpass and force a terminal password prompt:

```bash
cat ~/.ssh/id_ed25519.pub | SSH_ASKPASS= DISPLAY= \
  ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no zima \
  "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
```

Verify: `ssh -o BatchMode=yes zima hostname` should print the hostname
without prompting.

## 4. Neovim config

```bash
mkdir -p ~/.config/nvim
ln -s ~/Documents/ErykHalicki/init.lua ~/.config/nvim/init.lua
# or use init.vim instead
```

## 5. Tools referenced by the aliases

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
