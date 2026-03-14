### bash (Modern fzf & git setup)
```bash
# History optimization
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoreboth:erasedups
shopt -s histappend

# fzf & fd
export FZF_DEFAULT_COMMAND="fd --follow --hidden --strip-cwd-prefix --exclude .git --ignore-file ~/.fdignore"
export FZF_DEFAULT_OPTS='--preview="if [ -d {} ]; then eza -T --color=always {}; else bat --color=always {}; fi"'

# Terminal Safety
[[ -z "$TMUX" ]] && export TERM=xterm-256color

# Power Tools
fhist() { eval $(history | fzf +s --tac | sed 's/^[ ]*[0-9]*[ ]*//'); } # Interactive history search
fkill() { local pid; pid=$(ps -ef | sed 1d | fzf -m | awk '{print $2}'); [ -n "$pid" ] && echo "$pid" | xargs kill -${1:-9}; }
up() { local d=""; for ((i=1 ; i <= $1 ; i++)); do d=$d"../"; done; cd $d; } # up 3

# Optimized Search (frg)
frg() {
  local pattern="$1"
  [ -z "$pattern" ] && read -rp "Search pattern: " pattern
  results=$(rg --smart-case --no-ignore-vcs --line-number --no-heading "$pattern" | fzf -m --delimiter : --preview 'bat --style=numbers --color=always {1}') || return
  files=$(echo "$results" | cut -d: -f1 | sort -u)
  nvim -p $files
}

# Valgrind consolidated
valg() {
    local LOGFILE="valgrind_$(date +%Y%m%d_%H%M%S).log"
    valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes --log-file="$LOGFILE" "$@"
}

alias reload='source ~/.bashrc'
```

### Nerd fonts
```
mkdir -p ~/.local/share/fonts
cd ~/.local/share/fonts
curl -fLO https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/Hack/Regular/HackNerdFont-Regular.ttf
choco install nerd-fonts-hack
```

### alacritty.toml: AppData\Roaming\alacritty\alacritty.toml
```
[env]
TERM = "xterm-256color"
[font]
normal = {family="Hack Nerd Font Mono", style="Regular"}
bold = {family="Hack Nerd Font Mono", style="Bold"}
italic = {family="Hack Nerd Font Mono", style="Italic"}
size = 11.0
```

#### link to lua statically
g++ a.cpp /path/liblua.a -ldl

### vim
```
if exists('g:loaded_webdevicons')
    call webdevicons#refresh() 
endif

:Rg --no-ignore <pattern>

```

### sshfs
sshfs -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3 -o cache=yes -o kernel_cache  -o Ciphers=aes128-ctr  pi@192.168.1.13: mypi

### .ssh/config
```
Host *
  ServerAliveInterval 60
```

### ssh port forward
```
8888 local port on local machine: no need to be the same as user@localhost

ssh -L 0.0.0.0:8888:192.168.1.13:22 -o GatewayPorts=yes user@localhost
ssh pi@192.168.1.13 -o GatewayPorts=yes -L 8888:192.168.1.38:22
ssh -p 8888 pi@192.168.1.26
```
### ssh
```
/etc/ssh/sshd_config
X11Forwarding yes
X11DisplayOffset 10
X11UseLocalhost yes
ClientAliveInterval 60
ClientAliveCountMax 3

sudo systemctl restart sshd

```

### pivpn
pivpn -d
```
Iptables MASQUERADE rule is not set
Iptables FORWARD rule is not set
Save the current iptables rules (Debian/Ubuntu)
sudo iptables-save | sudo tee /etc/iptables/rules.v4
sudo apt update
sudo apt install iptables-persistent
```

### terminal images
* catimg
* chafa
* timg
* feh: X11 image viewer

### play in terminal
mpv --no-config --vo=tct <your videofile>
mpv --video-rotate=270 

### mac .zprofile
lua lib

export DYLD_LIBRARY_PATH="/opt/homebrew/lib/:$DYLD_LIBRARY_PATH"

### Termux for vim
export TERM=xterm-256color

### py on Windows
Computer\HKEY_CLASSES_ROOT\py_auto_file\shell\open\command

"C:\app\miniforge3\python.exe" "%1" %*

### git
```
# vim git: affect vim

git config --global core.autocrlf false
git config --global core.eol lf

# generate a merge commit
git merge --no-ff branch

# reset staging area to match latest commit
git reset --hard

# move branch tip to commit, del all commits after it
git reset --hard <commit>

# switch from submodule
git clean -fd
git checkout -f <branch>

```

### gdb TUI
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
layout split : 3 windows, source, assmbly , command

tui enable/disable
focus cmd
layout next

# Keybindings
Ctrl-p prev commandline
Ctrl-n next commandline
Ctrl-b move cursor backward
Ctrl-f move cursor forward
Alt-b move cursor one word backward
Alt-f move cursor one word forward
Ctrl-r search, select prev command
```

### run dearpygui on x201
export LIBGL_ALWAYS_SOFTWARE=1

### alacritty
set ttymouse=sgr : in .vimrc to enable mouse 

### raspberry pi onedrive
systemctl --user stop onedrive

### gdb
```
set substitute-path /build/project ~/dev/project
thread apply all bt
info line *xxxx
```
### launch valgrind inside gdb
1. set remote exec-file ./ex
2. set sysroot /
3. target extended-remote | vgdb --multi --vargs -q

### gdb server
* server: 
    * gdbserver :1234 ./myapp arg1 arg2
    * gdbserver --multi :1234 # no args
* host: gdb ./myapp
    * (gdb) target remote <target-ip>:1234
    * (gdb) target extended-remote <target-ip>:1234
    * (gdb) set substitute-path /build/project ~/dev/project
    * (gdb) set remote exec-file ./myapp
    * (gdb) set args arg1 arg2
    * (gdb) run arg1 arg2
* check current substitute-path: (gdb) show substitute-path

.gdbinit
```
set substitute-path /build/project ~/dev/project

define connect-target
    echo "connect to remote target\n"
    target remote-extended <ip>:1234 
end

symbol-file /host/...myapp

# Auto connect
connect-target

set remote exec-file /server/.../myapp
set args arg1 arg2
break main
```

### git diff meld
```
git config --global diff.tool meld
git config --global difftool.meld.cmd 'meld "$LOCAL" "$REMOTE"'
git config --global difftool.prompt false  # Optional: skips the "Launch meld?" prompt
git difftool commit1 commit2 # open file by file
git difftool -d commit1 commit2 # compare directory
git difftool -d main feature-branch
git diff commit1 commit2 # without meld


git difftool -d commit # compare to working tree
git difftool -d commit
```

### gdb valgrind
```
valgrind -q --vgdb-error=0 ./exe
gdb ./exe
(gdb)target remote | vgdb --pid=<XXXX>
(gdb>monitor leak_check
```

### gdb reverse debugging
```
record full
reverse-next
reverse-continue
```

### valgrind
```
--leak-check=full
--track-origins=yes # track origin of uninitialized values
--show-leak-kinds=all
--show-reachable=yes
--log-file=<filename>
--gen-suppressions=all
--suppressions=<filename>

export VALGRIND_OPTS="--leak-check=full --show-leak-kinds=all --track-origins=yes --log-file=valgrind_$(date +"%Y%m%d%H%M%S").log --error-exitcode=1"

valgrind --tool=callgrind
kcachegrind callgrind.out.<pid>

valgrind --tool=massif ./my_program
ms_print massif.out.<pid>

## fast valgrind
valgrind --leak-check=full --show-leak-kinds=definite,possible \
         --undef-value-errors=no --track-origins=no \
         --fair-sched=try \
         ./your_program

```

### AddressSanitizer
```
gcc -fsanitize=address -g 

# append it CXXFLAGS in Makefile
CXXFLAGS += $(SANITIZER_FLAGS)
make SANITIZER_FLAGS="-fsanitize=address -fsanitize=undefined"

```

### C/C++
```
# demangle symbols
nm -C x.o
nm x.o|c++filt

strace
strings -a x.o|egrep "GCC"

LD_DEBUG
* libs Show how libs are searched, loaded
```

### Help
tldr

curl cheat.sh/git

curl cheat.sh/ssh

### Linux
```
# RDP login
rm ~/.Xauthority
```

### Port forward on Windows
```
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=2201  connectaddress=127.0.0.1 connectport=22
netsh interface portproxy show all
netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=8080
netsh advfirewall firewall add rule name="Allow Port 2201" dir=in action=allow protocol=TCP localport=2201
```

### Docker
```

--mount type=bind,src=${HOME},dst=${HOME},bind-propagation=rshaed
-e HOME=${HOME}
--workdir ${HOME}
--name=${CONTAINER_NAME}
${IMAGE_NAME}:${TAG} sleep infinity

```

### Ranger
git clone https://github.com/alexanderjeurissen/ranger_devicons ~/.config/ranger/plugins/ranger_devicons

```
yp: copy full path to clipboard
ctrl + n: open a new tab
ctrl + w: close current tab
Tab: switch to next tab
Shift + Tab: Switch to previous tab
Space: mark [file](file)
V: toggle visual mode selection
uv: unmark files
:filter <pat>
:filter \.c
:reset
h: Goto parent directoy (move left)
l: enter a directory (move right)
yy: copy files
dd: cut files
pp: paste files
o: open sort menu
i: preview file

ya: select files to copy
yy
uy: unselect files
zd: set sort_directories_first!
E edit file


# scope.sh
# preview image
chafa -c 256 -s "${PV_WIDTH}x${PV_HEIGHT}" "${FILE_PATH}" && exit 4
exit 1;;
# show line number
env COLORTERM=8bit bat --color=always --style="plain,numbers"\
          -- "${FILE_PATH}" && exit 5
# .config/ranger/rifle.conf, may need
label open, has xdg-open = xdg-open "$@"

```
fzf : https://github.com/gotbletu/shownotes/blob/master/ranger_file_locate_fzf.md

https://obaranovskyi.com/environments/better-terminal-file-management-with-ranger

### lf
* C:\Users\xxx\AppData\Local\lf\lfrc
* Use winget to install the latest one, not choco
* delete files:
   * press d
   * :delete
* :set sortby ctime
* :set dirfirst!
* press z, s keys
* mA, 'A
* https://github.com/gokcehan/lf/wiki/Integrations
* copy files: y, p
* :filter .c
* :setfilter clean filter
* man lf
* copy: y
* cut: d
* paste: p
* rename: r

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
https://github.com/gokcehan/lf/blob/master/doc.md


### vifm
* ~/.vifm/vifmrc
* Windows: C:\Users\xxx\AppData\Roaming\Vifm\vifmrc
* export TERM=xterm-256color

### yazi
install on Windows:
* cargo build --profile release-windows --locked
* winget

### exa
exa --tree

### Test
* Test invalid inputs, edge cases: throw exception, return error code
* Assert invariants
* Use mock/stubs to simulate errors
* Test boundary values
* Performance, stress test
* Check memory errors: valgrind AddressSanitizer

### tmux
```
:capture-pane  copy visible content to buffer
:capture-pane -b temp-buffer -S - -E -
:capture-pane -b temp-buffer -S -100
:save-buffer /path/to/your/file.txt

-S - to capture from the start of the scrollback history.
-E - to capture to the end of the history.

tmux capture-pane -S - \; save-buffer - \; delete-buffer | xclip -selection clipboard

:capture-pane -S -
:save-buffer filename.txt
```



### vim wiki
```
<leader>ww  goto home
<leader>w<leader>w goto today

```

### py
* pip install termcolor

### Linux
```
fortune|cowsay
lsof
```

Core dump
- sudo sysctl -w kernel.core_pattern=core
- ulimit -c unlimited
- /etc/sysctl.conf:
    - kernel.core_pattern = core
    - sudo sysctl -p

### wezterm
```
* Ctrl-Tab: Navigate tabs
* copy inside vim:  Press Shift, use mouse to select
* Use mouse to select: copied to clipboard
* export DISPLAY or unset DISPLAY
```

### grep
```
-e (extended regex)
grep -e "http.*xxx" **/*.c - C 5 -n
-C (context)
-n (line number)

```

### Find disk space
du -h ~ | sort -hr | head -n 10

### fzf
```
export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

Use fd (https://github.com/sharkdp/fd) for listing path candidates.
- The first argument to the function ($1) is the base path to start traversal
- See the source code (completion.{bash,zsh}) for the details.
_fzf_compgen_path() {
  fd --hidden --exclude .git . "$1"
}

Use fd to generate the list for directory completion
_fzf_compgen_dir() {
  fd --type=d --hidden --exclude .git . "$1"
}
--- setup fzf theme ---
fg="#CBE0F0"
bg="#011628"
bg_highlight="#143652"
purple="#B388FF"
blue="#06BCE4"
cyan="#2CF9ED"

export FZF_DEFAULT_OPTS="--color=fg:${fg},bg:${bg},hl:${purple},fg+:${fg},bg+:${bg_highlight},hl+:${purple},info:${blue},prompt:${cyan},pointer:${cyan},marker:${cyan},spinner:${cyan},header:${cyan}"
```

### fzf-git.sh

source fzf-git.sh/fzf-git.sh

```
C-GF look for git files
C-GB look for git branches
C-GT looks for git tags
C-GR look for git remotes
C-GH look for git commit hashes
C-GS look for git stashes
C-GL look for git reflogs
C-GW look for git worktrees
C-GE look for git for-each-ref
```

### zoxide
trigger fzf: z, space+tab

### neovim
```
telescope
* <C-q> send all to quickfix
* <M-q> send selected to quickfix

```

### fd
* exclude files or directories:
    *--exclude(-E) .git
    * -E /mnt/external-drive
* skip file types: fd -E '*.bak'
* delete files: fd -H 'xxxx' -tf -X rm
* in git repos: not search in .gitignore, to disable it, use -I (--no-ignore)
* search all files/dirs: -HI
* exclude patterns in ignore files:
 * ~/.fdignore
 * ~/config/fd/ignore
 * 📝 %APPDATA%\fd\ignore (Windows)
```
*.bak
```

### ripgrep
* RIPGREP_CONFIG_PATH
* $HOME/.ripgreprc
* .config/git/ignore
```
--type-add
web:*.{html,css,js}*

--glob=!.git/*
--smart-case
```

### X server
```
Mobaxterm, local terminal: echo $DISPLAY
Windows ip
export DISPLAY=ip:1.0 inside docker
```

### find
```
-exec <cmd> {} +       run command in batches
-exec <cmd> {} \;      run command on each file

use -print0 with xargs -0 to handle filenames with spaces
use \(...\) to combine OR filters
combine with grep for content search inside found files

find . type f -name "*.py" -exec grep -H "TODO" {} \;
find . type f -empty # find empty files
-delete # delete found files
-size +10M # find files larger than 10M
-size -1k # find files smaller than 1k
-mtime -7 # find files modified in last 7 days

```

### grep
```
Use extended regex (-E)
grep -r -E "foo|bar" **/*.c
find . -name "*.c" | xargs grep "TODO"
grep -rn --include="*.c" "TODO"
grep -r -L "Copyright" **/*.c  # find files without copyright header
grep -rE "(TODOD|FIXME|BUG)" --include="*.c"  # find TODOs in C files

```

### wezterm
disable xterm mouse tracking modes: printf '\e[?1000l\e[?1002l\e[?1003l\e[?1006l'
