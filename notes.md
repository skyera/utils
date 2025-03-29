### bash
### Fzf & rg
export FZF_DEFAULT_COMMAND='rg --files'

export FZF_DEFAULT_OPTS="--preview 'bat --color=always {}'"

export RIPGREP_CONFIG_PATH=$HOME/.ripgreprc

export CPLUS_INCLUDE_PATH="$HOME/test/doctest/doctest:$HOME/test/nanobench/src/include:$HOME/test/FakeIt/single_header/doctest:$HOME/test/json/single_include:$HOME/test/stb:$HOME/test/LuaBridge/Source:$HOME/test/LuaBridge/Source/LuaBridge:$HOME/test/luajit/src:$CPLUS_INCLUDE_PATH"

export LIBRARY_PATH="$HOME/test/luajit/src:$LIBRARY_PATH"

export TERM=xterm-256color

export PROMPT_DIRTRIM=2

### Nerd fonts
mkdir -p ~/.local/share/fonts

cd ~/.local/share/fonts

curl -fLO https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/Hack/Regular/HackNerdFont-Regular.ttf

choco install nerd-fonts-hack

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
8888 local port on local machine: no need to be the same as user@localhost

ssh -L 0.0.0.0:8888:192.168.1.13:22 -o GatewayPorts=yes user@localhost

ssh pi@192.168.1.13 -o GatewayPorts=yes -L 8888:192.168.1.38:22

ssh -p 8888 pi@192.168.1.26

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

### vim git: affect vim
git config --global core.autocrlf false

git config --global core.eol lf

### gdb TUI
https://sourceware.org/gdb/current/onlinedocs/gdb.html/TUI-Keys.html
* ctrl-x a : enter /exit TUI mode
* ctrl-x 1 : Use TUI with only one window
* ctrl-x 2 : use TUI with 2 windows
* ctrl-x o : change active window

### run dearpygui on x201
export LIBGL_ALWAYS_SOFTWARE=1

### alacritty
set ttymouse=sgr : in .vimrc to enable mouse 

### raspberry pi onedrive
systemctl --user stop onedrive

### gdb
set substitute-path /build/project ~/dev/project




### launch valgrind inside gdb
1. set remote exec-file ./ex
2. set sysroot /
3. target extended-remote | vgdb --multi --vargs -q

### git diff mld
git config --global diff.tool meld

git config --global difftool.meld.cmd 'meld "$LOCAL" "$REMOTE"'

git config --global difftool.prompt false  # Optional: skips the "Launch meld?" prompt

git difftool <commit1> <commit2> # open file by file

git difftool -d <commit1> <commit2> # compare directory

git difftool -d main feature-branch

git diff <commit1> <commit2> # without meld

