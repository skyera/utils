# Personal Dev Notes

---

## Shell & Terminal Environment

### Bash Config
```bash
export TERM=tmux-256color
export PROMPT_DIRTRIM=2
export NEOVIM_BIN="/home/user/app/nvim-linux-x86_64/bin/nvim"

# autojump: cd first
[[ -s /usr/share/autojump/autojump.sh ]] && source /usr/share/autojump/autojump.sh

# zoxide
eval "$(zoxide init bash)"

alias reload='source ~/.bashrc'
```

### Docker Helper
```bash
dexec() {
    local cid=$(docker ps --format '{{.Names}}' | grep ${USER}|fzf)
    [ -n "$cid" ] && docker exec -it -u ${USER} "$cid" bash
}
```

### Nerd Fonts
```bash
# Linux
mkdir -p ~/.local/share/fonts
cd ~/.local/share/fonts
curl -fLO https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/Hack/Regular/HackNerdFont-Regular.ttf

# macOS (Homebrew)
brew tap homebrew/cask-fonts
brew install --cask font-jetbrains-mono-nerd-font

# Windows
choco install nerd-fonts-hack
```

### Alacritty
Config path: `AppData\Roaming\alacritty\alacritty.toml`
```toml
[env]
TERM = "xterm-256color"
[font]
normal = {family="Hack Nerd Font Mono", style="Regular"}
bold = {family="Hack Nerd Font Mono", style="Bold"}
italic = {family="Hack Nerd Font Mono", style="Italic"}
size = 11.0
```

### WezTerm
```
* Ctrl-Tab: Navigate tabs
* copy inside vim: Press Shift, use mouse to select
* Use mouse to select: copied to clipboard
* export DISPLAY or unset DISPLAY
```

Disable xterm mouse tracking modes:
```bash
printf '\e[?1000l\e[?1002l\e[?1003l\e[?1006l'
```

### tmux
```
:capture-pane                  copy visible content to buffer
:capture-pane -b temp-buffer -S - -E -
:capture-pane -b temp-buffer -S -100
:save-buffer /path/to/your/file.txt

# -S - : capture from start of scrollback history
# -E - : capture to end of history

tmux capture-pane -S - \; save-buffer - \; delete-buffer | xclip -selection clipboard
```

### Terminal Images & Video
```
catimg
chafa
timg
feh: X11 image viewer
```

Play video in terminal:
```bash
mpv --no-config --vo=tct <your videofile>
mpv --video-rotate=270
```

### macOS .zprofile
```bash
export DYLD_LIBRARY_PATH="/opt/homebrew/lib/:$DYLD_LIBRARY_PATH"
```

### Termux for Vim
```bash
export TERM=xterm-256color
```

---

## Editors

### Vim
```vim
if exists('g:loaded_webdevicons')
    call webdevicons#refresh()
endif

" Enable mouse in alacritty
set ttymouse=sgr

" Rg search ignoring .gitignore
:Rg --no-ignore <pattern>
```

### Neovim
```
telescope
* <C-q> send all to quickfix
* <M-q> send selected to quickfix
```

### Vim Wiki
```
<leader>ww        goto home
<leader>w<leader>w goto today
```

---

## File Managers

### Ranger
```bash
git clone https://github.com/alexanderjeurissen/ranger_devicons ~/.config/ranger/plugins/ranger_devicons
```

Commands:
```
yp:              copy full path to clipboard
ctrl + n:        open a new tab
ctrl + w:        close current tab
Tab:             switch to next tab
Shift + Tab:     switch to previous tab
Space:           mark file
V:               toggle visual mode selection
uv:              unmark files
h:               goto parent directory (move left)
l:               enter a directory (move right)
yy:              copy files
dd:              cut files
pp:              paste files
o:               open sort menu
i:               preview file
E:               edit file

:filter <pat>
:filter \.c
:reset

# rename files
select files using Space
Type :bulkrename
Edit in text editor, exit

ya:              select files to copy
yy
uy:              unselect files
zd:              set sort_directories_first!
```

#### scope.sh
```bash
# preview image
chafa -c 256 -s "${PV_WIDTH}x${PV_HEIGHT}" "${FILE_PATH}" && exit 4
exit 1;;

# show line number
env COLORTERM=8bit bat --color=always --style="plain,numbers" \
    -- "${FILE_PATH}" && exit 5

# .config/ranger/rifle.conf, may need
label open, has xdg-open = xdg-open "$@"
```

* fzf + ranger: https://github.com/gotbletu/shownotes/blob/master/ranger_file_locate_fzf.md
* https://obaranovskyi.com/environments/better-terminal-file-management-with-ranger

### lf
Config path:
* Linux: `~/.config/lf/lfrc`
* Windows: `C:\Users\xxx\AppData\Local\lf\lfrc`

Tips:
```
* Use winget to install the latest one, not choco
* delete files: press d, then :delete
* :set sortby ctime
* :set dirfirst!
* press z, s keys
* mA, 'A
* copy files: y, p
* :filter , press ENTER, then inpyt .c
* :setfilter clean filter
* man lf
* copy: y
* cut: d
* paste: p
* rename: r
```

#### lfrc snippets
```
map zh set hidden!
map zr set reverse!
map zn set info
map zs set info size
map zt set info time
map za set info size:time
map sn :set sortby natural; set info
map ss :set sortby size; set info size
map st :set sortby time; set info time
map sa :set sortby atime; set info atime
map sc :set sortby ctime; set info ctime
map se :set sortby ext; set info
map gh cd ~
map <space> :toggle; down
```

* https://github.com/gokcehan/lf/wiki/Integrations
* https://github.com/gokcehan/lf/blob/master/doc.md

### vifm
Config path:
* Linux: `~/.vifm/vifmrc`
* Windows: `C:\Users\xxx\AppData\Roaming\Vifm\vifmrc`
* `export TERM=xterm-256color`

### yazi
Install on Windows:
* `cargo build --profile release-windows --locked`
* `winget`

### exa
```bash
exa --tree
```

---

## Search & Find

### fzf

#### Shell Integration
```bash
eval "$(fzf --bash)"
```

#### Environment
```bash
export FZF_DEFAULT_COMMAND="fd --follow --hidden --ignore-file ~/.fdignore"
# on Windows: fd --no-ignore-vcs --type file --follow --hidden --ignore-file c:\users\zliu\.fdignore

export FZF_DEFAULT_OPTS="--preview 'bat --color=always {}'"

export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"
```

#### Completions
```bash
# Use fd for listing path candidates
_fzf_compgen_path() {
  fd --hidden --exclude .git . "$1"
}

# Use fd for directory completion
_fzf_compgen_dir() {
  fd --type=d --hidden --exclude .git . "$1"
}
```

#### Theme
```bash
fg="#CBE0F0"
bg="#011628"
bg_highlight="#143652"
purple="#B388FF"
blue="#06BCE4"
cyan="#2CF9ED"

export FZF_DEFAULT_OPTS="--color=fg:${fg},bg:${bg},hl:${purple},fg+:${fg},bg+:${bg_highlight},hl+:${purple},info:${blue},prompt:${cyan},pointer:${cyan},marker:${cyan},spinner:${cyan},header:${cyan}"
```

#### cheat.sh + fzf
```bash
fzfc() {
    curl -ks cht\.sh/$(
      curl -ks cht\.sh/:list | \
      IFS=+ fzf --preview 'curl -ks http://cht.sh{}' -q "$*"); }
```

### fd
```
* exclude files or directories:
    --exclude(-E) .git
    -E /mnt/external-drive
* skip file types: fd -E '*.bak'
* delete files: fd -H 'xxxx' -tf -X rm
* in git repos: not search in .gitignore; to disable it, use -I (--no-ignore)
* search all files/dirs: -HI
* exclude patterns in ignore files:
    ~/.fdignore
    ~/.config/fd/ignore
    %APPDATA%\fd\ignore (Windows)
```

Example `.fdignore`:
```
*.bak
```

### ripgrep
```
* RIPGREP_CONFIG_PATH
* $HOME/.ripgreprc
* .config/git/ignore
```

Example `.ripgreprc`:
```
--type-add
web:*.{html,css,js}*

--glob=!.git/*
--smart-case
```

### find
```bash
# Arguments
-type [f|d|l]      # f: file, d: directory, l: symlink
-name, -iname      # match filename (-i: case-insensitive). ALWAYS quote wildcards!
-path              # match full path pattern
-maxdepth N        # limit search depth
-size [+-]N        # match size (e.g. +10M, -1k)
-mtime [+-]N       # match modification time in days (e.g. -7: last 7 days)
-empty             # match empty files/directories
-delete            # delete matching items (CAUTION: runs immediately)
-exec <cmd> {} \;  # run command once per file ({} is placeholder)
-exec <cmd> {} +   # run command in batches (faster)
-print0            # print null-terminated (use with xargs -0)
-prune             # skip a directory entirely (used with -path)

# Examples
find . -type f -name "*.py"                   # Standard search
find . -maxdepth 1 -type f                    # Search current dir only
find . \( -name "*.py" -o -name "*.sh" \)     # OR filter
find . -type f ! -name "*.git*"               # NOT filter
find . -type d -empty -delete                 # Delete empty directories
find . -path "./.git" -prune -o -print        # Prune (skip) .git folder
find . -type f -name "*.txt" -print0 | xargs -0 rm   # Handle spaces safely

# Content search inside found files
find . -type f -name "*.py" -exec grep -H "TODO" {} \;
```

### grep
```bash
# Options
-E, -e        # -E: extended regex; -e: specify pattern (useful for multiple or starting with -)
-i            # ignore case
-C, -A, -B    # -C: Context, -A: After, -B: Before (show lines around the match)
-n            # show line number
-w            # whole word (match only exact word)
-v            # invert match (show lines that do NOT match)
-o            # only matching part (show only the matched string, not the whole line)
-F            # fixed strings (faster, no regex parsing)
-I            # ignore binary files
-r, -R        # recursive search (-R follows symlinks)
-l, -L        # -l: files WITH matches; -L: files WITHOUT matches

# Recursive with filters
grep -rI --exclude-dir={.git,node_modules} --include="*.c" "pattern" .

# Advanced logic
grep "foo" file | grep "bar"          # AND logic
grep -E "foo|bar" file                # OR logic
grep -r -L "Copyright" **/*.c         # find files WITHOUT match

# Examples
grep -r -E "foo|bar" **/*.c
find . -name "*.c" | xargs grep "TODO"
grep -rn --include="*.c" "TODO"
grep -rE "(TODO|FIXME|BUG)" --include="*.c"  # find TODOs in C files

# Pro Tip: Standard vs Pro
# Standard: grep -r "TODO" .
# Pro:      grep -rI --exclude-dir=.git --include="*.c" -w "TODO" .
```

### xargs
```bash
# Parallel Processing (use 4 cores)
find . -name "*.log" | xargs -P 4 -I {} gzip {}

# Interactive Confirmation
find . -name "*.tmp" | xargs -p rm

# Search content in specific files only
find . -type f \( -name "*.env" -o -name "*.config" \) | xargs grep "API_KEY"

# Kill processes by keyword
pgrep -f python | xargs kill -9

# Run multiple commands per item
find . -name "*.sh" | xargs -I {} sh -c 'chmod +x {}; cp {} ~/bin/'

# Download from a list
cat urls.txt | xargs -n 1 curl -O

# Safe handling of spaces (with find -print0)
find . -type f -name "*.txt" -print0 | xargs -0 rm

# Batch copy using target flag (fastest)
find . -name "*.jpg" | xargs cp -t /backup/
```

---

## Version Control

### git
```bash
# Manual .gitconfig location:
# Linux/macOS: ~/.gitconfig
# Windows:     C:\Users\<User>\.gitconfig

# 1. Set your identity once on each machine:
# git config --global user.name "Zhigang"
# git config --global user.email "your-email@example.com"

# 2. Link your repo config (aliases, settings):
# git config --global include.path "C:/test/utils/.gitconfig"

# generate a merge commit
git merge --no-ff <branch>

# reset staging area to match latest commit
git reset --hard

# move branch tip to commit, delete all commits after it
git reset --hard <commit>

# recover from submodule issues
git clean -fd
git checkout -f <branch>
```

### git diff with meld
```bash
git config --global diff.tool meld
git config --global difftool.meld.cmd 'meld "$LOCAL" "$REMOTE"'
git config --global difftool.prompt false  # Optional: skips the "Launch meld?" prompt

git difftool commit1 commit2      # open file by file
git difftool -d commit1 commit2  # compare directory
git difftool -d main feature-branch

git diff commit1 commit2          # without meld
git difftool -d commit            # compare to working tree
```

### fzf-git.sh
```bash
source fzf-git.sh/fzf-git.sh
```
```
C-GF  look for git files
C-GB  look for git branches
C-GT  looks for git tags
C-GR  look for git remotes
C-GH  look for git commit hashes
C-GS  look for git stashes
C-GL  look for git reflogs
C-GW  look for git worktrees
C-GE  look for git for-each-ref
```

---

## Debugging & Profiling

### gdb

#### TUI
```
https://sourceware.org/gdb/current/onlinedocs/gdb.html/TUI-Keys.html
* ctrl-x a : enter /exit TUI mode
* ctrl-x 1 : Use TUI with only one window
* ctrl-x 2 : use TUI with 2 windows
* ctrl-x o : change active window
* ctrl-L : refresh screen

https://beej.us/guide/bggdb/
info win
fs next
fs src : focus set to src window
layout src : src on top, command window on bottom
layout asm : assembly on top
layout split : 3 windows, source, assembly, command

tui enable/disable
focus cmd
layout next
```

#### Keybindings
```
Ctrl-p prev commandline
Ctrl-n next commandline
Ctrl-b move cursor backward
Ctrl-f move cursor forward
Alt-b move cursor one word backward
Alt-f move cursor one word forward
Ctrl-r search, select prev command
```

#### Commands
```
set substitute-path /build/project ~/dev/project
thread apply all bt
info line *xxxx
```

#### Reverse Debugging
```
record full
reverse-next
reverse-continue
```

### gdb Server / Remote

#### .gdbinit
```text
set substitute-path /build/project ~/dev/project

define connect-target
    echo "connect to remote target\n"
    target extended-remote <ip>:1234
end

symbol-file /host/...myapp

# Auto connect
connect-target

set remote exec-file /server/.../myapp
set args arg1 arg2
break main
```

#### Server
```bash
gdbserver :1234 ./myapp arg1 arg2
gdbserver --multi :1234
```

#### Host
```text
target remote <target-ip>:1234
target extended-remote <target-ip>:1234
set substitute-path /build/project ~/dev/project
set remote exec-file ./myapp
set args arg1 arg2
run arg1 arg2
show substitute-path
```

### Valgrind

#### Options
```
--leak-check=full
--track-origins=yes        # track origin of uninitialized values
--show-leak-kinds=all
--show-reachable=yes
--log-file=<filename>
--gen-suppressions=all
--suppressions=<filename>
```

#### Shell Helpers
```bash
valg-save() {
    local output_file="valgrind_$(date +%Y%m%d_%H%M%S).log"
    valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes --log-file="$output_file" "$@"
    echo "Valgrind output saved to: $output_file"
}

valgrind_exe() {
    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    local LOGFILE="valgrind_${ts}.log"
    echo "Valgrind output saved to: $LOGFILE"
    local VALGRIND_OPTS="--leak-check=full --show-leak-kinds=all --track-origins=yes --log-file=$LOGFILE"
    valgrind $VALGRIND_OPTS "$@"
}

export VALGRIND_OPTS="--leak-check=full --show-leak-kinds=all --track-origins=yes --log-file=valgrind_$(date +"%Y%m%d%H%M%S").log --error-exitcode=1"
```

#### Tools
```bash
valgrind --tool=callgrind ./myapp
kcachegrind callgrind.out.<pid>

valgrind --tool=massif ./my_program
ms_print massif.out.<pid>
```

#### Fast Valgrind
```bash
valgrind --leak-check=full --show-leak-kinds=definite,possible \
         --undef-value-errors=no --track-origins=no \
         --fair-sched=try \
         ./your_program
```

#### Valgrind + gdb
```bash
valgrind -q --vgdb-error=0 ./exe
gdb ./exe
(gdb) target remote | vgdb --pid=<XXXX>
(gdb) monitor leak_check
```

#### Launch Valgrind Inside gdb
```text
1. set remote exec-file ./ex
2. set sysroot /
3. target extended-remote | vgdb --multi --vargs -q
```

### AddressSanitizer
```bash
gcc -fsanitize=address -g

# append to CXXFLAGS in Makefile
CXXFLAGS += $(SANITIZER_FLAGS)
make SANITIZER_FLAGS="-fsanitize=address -fsanitize=undefined"
```

---

## Build & Compile

### C/C++
```bash
# demangle symbols
nm -C x.o
nm x.o | c++filt

strace
strings -a x.o | egrep "GCC"

LD_DEBUG
* libs Show how libs are searched, loaded
```

#### Include/Library Paths
```bash
export CPLUS_INCLUDE_PATH="$HOME/test/doctest/doctest:$HOME/test/nanobench/src/include:$HOME/test/FakeIt/single_header/doctest:$HOME/test/json/single_include:$HOME/test/stb:$HOME/test/LuaBridge/Source:$HOME/test/LuaBridge/Source/LuaBridge:$HOME/test/luajit/src:$CPLUS_INCLUDE_PATH"
export LIBRARY_PATH="$HOME/test/luajit/src:$LIBRARY_PATH"
```

### Static Lua Linking
```bash
g++ a.cpp /path/liblua.a -ldl
```

### Python on Windows
Fix for .py file associations not passing command-line arguments. Ensure registry keys include `%*` at the end of the command string.

Registry Keys:
- `HKEY_CLASSES_ROOT\Applications\python.exe\shell\open\command`
- `HKEY_CLASSES_ROOT\py_auto_file\shell\open\command`

Value:
`"C:\app\miniforge3\python.exe" "%1" %*`

### Python
```bash
pip install termcolor
```

### DearPyGui on x201
```bash
export LIBGL_ALWAYS_SOFTWARE=1
```

---

## Networking & Remote

### SSH Config
```
Host *
  ServerAliveInterval 60
```

### SSH Server Config
```
/etc/ssh/sshd_config
X11Forwarding yes
X11DisplayOffset 10
X11UseLocalhost yes
ClientAliveInterval 60
ClientAliveCountMax 3

sudo systemctl restart sshd
```

### SSH Port Forwarding
```
# local port on local machine: no need to be the same as user@localhost

ssh -L 0.0.0.0:8888:192.168.1.13:22 -o GatewayPorts=yes user@localhost
ssh pi@192.168.1.13 -o GatewayPorts=yes -L 8888:192.168.1.38:22
ssh -p 8888 pi@192.168.1.26
```

### sshfs
```bash
sshfs -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3 \
      -o cache=yes -o kernel_cache -o Ciphers=aes128-ctr \
      pi@192.168.1.13: mypi
```

### X Server / DISPLAY
```
MobaXterm, local terminal: echo $DISPLAY
Windows IP
export DISPLAY=<ip>:1.0 inside docker
```

### PiVPN
```bash
pivpn -d
```
```
Iptables MASQUERADE rule is not set
Iptables FORWARD rule is not set
Save the current iptables rules (Debian/Ubuntu)
sudo iptables-save | sudo tee /etc/iptables/rules.v4
sudo apt update
sudo apt install iptables-persistent
```

### Windows Port Forwarding
```cmd
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=2201 connectaddress=127.0.0.1 connectport=22
netsh interface portproxy show all
netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=8080
netsh advfirewall firewall add rule name="Allow Port 2201" dir=in action=allow protocol=TCP localport=2201
```

---

## System & Docker

### Linux
```bash
# RDP login
rm ~/.Xauthority

# core dumps
sudo sysctl -w kernel.core_pattern=core
ulimit -c unlimited
# /etc/sysctl.conf:
#     kernel.core_pattern = core
#     sudo sysctl -p

fortune | cowsay
lsof
```

### Disk Space
```bash
du -h ~ | sort -hr | head -n 10
```

### Docker
```bash
# Run with bind mounts
docker run ... \
  --mount type=bind,src=${HOME},dst=${HOME},bind-propagation=rshared \
  -e HOME=${HOME} \
  --workdir ${HOME} \
  --name=${CONTAINER_NAME} \
  ${IMAGE_NAME}:${TAG} sleep infinity
```

---

## Testing
```
* Test invalid inputs, edge cases: throw exception, return error code
* Assert invariants
* Use mock/stubs to simulate errors
* Test boundary values
* Performance, stress test
* Check memory errors: valgrind AddressSanitizer
```

---

## Help & References
```bash
tldr <command>

curl cheat.sh/git
curl cheat.sh/ssh
```
