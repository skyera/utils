### bash
```
### Fzf & rg
# /.gitignore affect rg
export FZF_DEFAULT_COMMAND='rg --files'
export FZF_DEFAULT_COMMAND="fd --type file --follow --hidden"
export FZF_DEFAULT_OPTS="--preview 'bat --color=always {}'"
export RIPGREP_CONFIG_PATH=$HOME/.ripgreprc
export CPLUS_INCLUDE_PATH="$HOME/test/doctest/doctest:$HOME/test/nanobench/src/include:$HOME/test/FakeIt/single_header/doctest:$HOME/test/json/single_include:$HOME/test/stb:$HOME/test/LuaBridge/Source:$HOME/test/LuaBridge/Source/LuaBridge:$HOME/test/luajit/src:$CPLUS_INCLUDE_PATH"
export LIBRARY_PATH="$HOME/test/luajit/src:$LIBRARY_PATH"
export TERM=xterm-256color
export PROMPT_DIRTRIM=2

# autojump: cd first
[[ -s /usr/share/autojump/autojump.sh ]] && source /usr/share/autojump/autojump.sh

# cheat.sh + fzf: fzfc git merge
fzfc() {
    curl -ks cht\.sh/$(
      curl -ks cht\.sh/:list | \
      IFS=+ fzf --preview 'curl -ks http://cht.sh{}' -q "$*"); }
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
```
### launch valgrind inside gdb
1. set remote exec-file ./ex
2. set sysroot /
3. target extended-remote | vgdb --multi --vargs -q

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

### valgrind
```
--leak-check=full
--track-origins=yes # track origin of uninitialized values
--show-leak-kinds=all
--show-reachable=yes
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
```
yp: copy full path to clipboard
ctrl + n: open a new tab
ctrl + w: close current tab
Tab: switch to next tab
Shift + Tab: Switch to previous tab
Space: mark file
V: toggle visual mode selection
uv: unmark files
:filter
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


# scope.sh
# preview image
chafa -c 256 -s "${PV_WIDTH}x${PV_HEIGHT}" "${FILE_PATH}" && exit 4
exit 1;;
# show line number
env COLORTERM=8bit bat --color=always --style="plain,numbers"\
          -- "${FILE_PATH}" && exit 5


```
fzf : https://github.com/gotbletu/shownotes/blob/master/ranger_file_locate_fzf.md

https://obaranovskyi.com/environments/better-terminal-file-management-with-ranger

### lf
C:\Users\xxx\AppData\Local\lf\lfrc
* delete files:
   * press d
   * :delete
* :set sortby ctime
* :set dirfirst!

```
set shell powershell
 
# change the default open command to work in powerShell
cmd open &start $Env:f
# edit with vim
map e $vim $Env:f
# page through any file with bat
# paging=always so that shorter files don't immediately exit back to lf
map i $bat --paging=always $Env:f
# use "bat -p" (plain pager) also for viewing lf docs
cmd doc $lf -doc | bat -p

set incsearch true
set number true
set preview true
set previewer "c:\\app\\bin\\lf-preview.bat"
set drawbox true
map <m-1> select


set promptfmt "\033[32;1m%u@%h\033[0m:\033[34;1m%d 📁 \033[0m\033[1m%f\033[0m"
 
# https://github.com/gokcehan/lf/wiki/Integrations#quicklook
# winget install QL-Win.QuickLook
map V $C:\Users\zliu\AppData\Local\Programs\QuickLook\QuickLook.exe $env:f

cmd fzf_find $C:/app/bin/fzf_find.bat
map zz :fzf_find

```

lf-preview.bat
```
@echo off
REM Use bat to preview the file with paging and syntax highlighting
REM lf passes the file path as the first argument

bat --style="plain,numbers" --color=always --paging=never "%1"

```
fzf_find.bat
```
@echo off
setlocal enabledelayedexpansion

:: Call fd and fzf
fd . --type f | fzf --preview "bat --color=always --style=numbers {}" > "%TEMP%\fzf_result.txt"

:: Read result
set /p selected_file=<"%TEMP%\fzf_result.txt"

:: Replace backslashes with forward slashes (lf prefers Unix-style paths)
set "selected_file=!selected_file:\=/!"

:: If selected, send to lf
if not "!selected_file!"=="" (
    lf -remote "send %id% select '!selected_file!'"
)

del "%TEMP%\fzf_result.txt"
endlocal

```

### vifm
~/vifm/vimrc

Windows: C:\Users\xxx\AppData\Roaming\Vifm\vifmrc
export TERM=xterm-256color
```
" Enable preview mode on startup
view!
set vifminfo+=tui

" Preview text and code files with bat
fileviewer *.txt,*.md,*.c,*.h,*.py,*.sh,*.js,*.json,*.cpp,*.java,*.go,*.lua bat --color=always --style=numbers %c

" Fallback for other files (non-directories)
fileviewer *.[!d]/ bat --color=always --style=plain %c

" Preview directories with ls
fileviewer */ ls --color=always %c
fileviewer .*/ ls --color=always %c

" Toggle preview with 'w'
nnoremap w :view!<cr>

```
