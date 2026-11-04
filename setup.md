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

## 6. Citation sources for `\cite{}` completion

`bibcite.lua` completes keys inside `\cite{...}` (and `\citep`, `\citet`, ...) by
fuzzy-matching key, title, authors, year, venue or abstract. It searches, in order:

1. **Project bibs**: every `.bib` in the current file's folder and up to 3
   parent folders (stopping at `~`).
2. **Project sources**: `source =` lines in the nearest `.bibcite` above the
   current file.
3. **Global sources**: `source =` lines in `~/.config/bibcite/config`.

When a key appears in more than one file, the earliest wins, so a project's own
bib overrides an external copy. Results from 2 and 3 are labelled with their file,
e.g. `[library] Fu et al. 2026 · LeWAM: ...`.

Confirming a key that only an external source has copies the entry into the
project's bib: the `target =` file from `.bibcite`, else the nearest project
`.bib`. It skips keys the target already has. If the target is open in nvim the
entry goes into the buffer, which is saved only if it had no unsaved changes.
Only standard BibTeX fields are copied (`COPY_FIELDS` in `bibcite.lua`), so
reference-manager fields like `file`, `keywords` and `urldate` stay in the source.

Both config files use `key = value` lines; `#` lines are comments, `~` expands,
and relative paths resolve against the config file's folder.

```
# ~/.config/bibcite/config: searched in every project
source = ~/Zotero/library.bib
```

```
# <latex project root>/.bibcite: this project only
source = ../other-paper/refs.bib
source = ~/papers/shared.bib
target = ref.bib
```

`~/Zotero/library.bib` is a Better BibTeX auto-export: in Zotero, right-click
My Library → Export Library… → Better BibTeX, tick "Keep updated", save to
`~/Zotero/library.bib`. Zotero rewrites it whenever the library changes.

## Files

| File | Purpose |
|------|---------|
| `useful_aliases.bash` | Portable shell aliases/functions |
| `init.lua` / `init.vim` | Neovim config |
| `bibcite.lua` | nvim-cmp source for `\cite{}`: fuzzy search over nearby `.bib` files plus `.bibcite` / global sources, copying picked external entries into the project bib (see 6; loaded by `init.lua`) |
| `prose_stats.lua` | lualine word count + reading time for md/tex/txt; tex uses `texcount` and includes `\input` files (loaded by `init.lua`) |
| `walle-ascii-art.txt` | neofetch ascii art |
| `clang-format` | C/C++ formatting rules |

## Browser terminal (ttyd + termbridge)

A terminal in a Brave tab, so `:Open` in nvim shows PDFs in the Google Scholar reader. ttyd runs
on the machine you sit at, on localhost only, and every session runs under `termbridge`. nvim sends
`:Open`ed files and OSC 52 clipboard traffic through the terminal, so they land on that machine
however many ssh hops away nvim is; remote hosts need only this init.lua. Files go to
`~/Downloads/term` under unique names.

Install ttyd (`brew install ttyd`; on Linux grab the static binary into `~/.local/bin` from
https://github.com/tsl0922/ttyd/releases), then start it at login:

```bash
# macOS
cp ~/Documents/ErykHalicki/term.plist ~/Library/LaunchAgents/com.erykhalicki.term.plist
launchctl load ~/Library/LaunchAgents/com.erykhalicki.term.plist

# Ubuntu
systemctl --user link ~/Documents/ErykHalicki/term.service
systemctl --user enable --now term.service
```

`term` serves ttyd's page with `term-page.js` added, which supplies what ttyd's options can't: light/dark
colours that follow the system, the iTerm2 profile's key mappings, a visual bell and the tab icon.

`~/Documents/ErykHalicki/term url` prints the address to bookmark. Add `?arg=ssh&arg=<host>` for a
tab that opens straight on another machine. Don't open another machine's ttyd remotely: ssh from
your local one, so files open in front of you. In Brave, enable "Allow access to file URLs" for the
Scholar PDF Reader extension.
