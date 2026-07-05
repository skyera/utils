#!/bin/bash
# deploy.sh - Copy configuration files to $HOME

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
    echo "Usage: ./deploy.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help      Show this help message"
    echo "  -v, --vim       Use myvimrc as init.vim (Vimscript style)"
    echo "  -l, --lua       Use .config/nvim as Neovim config (Lua style, default)"
    echo ""
    echo "By default, Neovim Lua configuration is deployed."
}

# Default choice
NVIM_CHOICE="lua"

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) show_help; exit 0 ;;
        -v|--vim) NVIM_CHOICE="vim"; shift ;;
        -l|--lua) NVIM_CHOICE="lua"; shift ;;
        *) echo "Unknown parameter passed: $1"; show_help; exit 1 ;;
    esac
done

# 1. Ensure bin exists (for scripts)
mkdir -p ~/bin

# 2. Helper function to copy
deploy_file() {
    local src="$1"
    local dest="$2"
    
    if [ ! -f "$src" ]; then
        echo "Warning: Source $src does not exist. Skipping."
        return
    fi

    # Create destination directory if it doesn't exist
    mkdir -p "$(dirname "$dest")"

    if [ -f "$dest" ]; then
        if cmp -s "$src" "$dest"; then
            echo "Skipping $dest (already up to date)"
            return
        fi
        echo "Backing up existing $dest to ${dest}.bak"
        cp "$dest" "${dest}.bak"
    fi
    
    cp "$src" "$dest"
    echo "Deployed $dest"
}

# 3. Deploy files
echo "Deploying dotfiles..."

# Handle .bashrc sourcing instead of overwriting
deploy_file "$REPO_DIR/mybashrc" "$HOME/.mybashrc"
BASHRC_LINE="[ -f ~/.mybashrc ] && . ~/.mybashrc"
if ! grep -Fxq "$BASHRC_LINE" "$HOME/.bashrc" 2>/dev/null; then
    echo "Adding sourcing line to ~/.bashrc"
    echo -e "\n# Source personal aliases and functions\n$BASHRC_LINE" >> "$HOME/.bashrc"
fi

# Also add to .zshrc on macOS (default shell since Catalina)
if [ "$(uname)" = "Darwin" ]; then
    if ! grep -Fxq "$BASHRC_LINE" "$HOME/.zshrc" 2>/dev/null; then
        echo "Adding sourcing line to ~/.zshrc"
        echo -e "\n# Source personal aliases and functions\n$BASHRC_LINE" >> "$HOME/.zshrc"
    fi
fi

deploy_file "$REPO_DIR/myvimrc"    "$HOME/.vimrc"

# Neovim configuration
if [ "$NVIM_CHOICE" == "lua" ]; then
    if [ -d "$REPO_DIR/.config/nvim" ]; then
        echo "Deploying Neovim Lua configuration..."
        mkdir -p "$HOME/.config/nvim"
        [ -f "$HOME/.config/nvim/init.vim" ] && rm "$HOME/.config/nvim/init.vim"
        cp -r "$REPO_DIR/.config/nvim/"* "$HOME/.config/nvim/"
        echo "Deployed Neovim configuration to $HOME/.config/nvim"
    fi
else
    echo "Deploying Neovim Vimscript configuration..."
    # Remove Lua config directory if it exists to avoid conflicts
    [ -d "$HOME/.config/nvim/lua" ] && rm -rf "$HOME/.config/nvim/lua"
    [ -f "$HOME/.config/nvim/init.lua" ] && rm "$HOME/.config/nvim/init.lua"
    deploy_file "$REPO_DIR/myvimrc" "$HOME/.config/nvim/init.vim"
fi

deploy_file "$REPO_DIR/.tigrc"      "$HOME/.tigrc"
deploy_file "$REPO_DIR/.vifm/vifmrc" "$HOME/.vifm/vifmrc"
deploy_file "$REPO_DIR/.tmux.conf" "$HOME/.tmux.conf"
deploy_file "$REPO_DIR/.ripgreprc" "$HOME/.ripgreprc"
deploy_file "$REPO_DIR/.gdbinit"    "$HOME/.gdbinit"
deploy_file "$REPO_DIR/.gitconfig" "$HOME/.gitconfig"

# Config directories
deploy_file "$REPO_DIR/.config/ranger/rc.conf"      "$HOME/.config/ranger/rc.conf"
deploy_file "$REPO_DIR/.config/ranger/commands.py"  "$HOME/.config/ranger/commands.py"
deploy_file "$REPO_DIR/.config/ranger/scope.sh"     "$HOME/.config/ranger/scope.sh"
if [ -d "$REPO_DIR/.config/ranger/colorschemes" ]; then
    mkdir -p "$HOME/.config/ranger/colorschemes"
    cp -r "$REPO_DIR/.config/ranger/colorschemes/"* "$HOME/.config/ranger/colorschemes/"
fi
chmod +x "$HOME/.config/ranger/scope.sh" 2>/dev/null
deploy_file "$REPO_DIR/.config/lf/lfrc"             "$HOME/.config/lf/lfrc"
deploy_file "$REPO_DIR/.config/lf/icons"            "$HOME/.config/lf/icons"
deploy_file "$REPO_DIR/.config/lf/colors"           "$HOME/.config/lf/colors"
deploy_file "$REPO_DIR/.config/git/ignore"          "$HOME/.config/git/ignore"
deploy_file "$REPO_DIR/.config/fd/ignore"           "$HOME/.config/fd/ignore"

# Yazi configuration
echo "Deploying Yazi configuration..."
deploy_file "$REPO_DIR/.config/yazi/theme.toml"             "$HOME/.config/yazi/theme.toml"
deploy_file "$REPO_DIR/.config/yazi/keymap.toml"            "$HOME/.config/yazi/keymap.toml"
# Note: yazi_windows.toml is present but usually yazi expects yazi.toml on Linux
if [ -f "$REPO_DIR/.config/yazi/yazi.toml" ]; then
    deploy_file "$REPO_DIR/.config/yazi/yazi.toml"          "$HOME/.config/yazi/yazi.toml"
fi

# Binaries
echo "Deploying binaries to ~/bin/..."
for f in "$REPO_DIR/bin/"*; do
    if [ -f "$f" ]; then
        deploy_file "$f" "$HOME/bin/$(basename "$f")"
        chmod +x "$HOME/bin/$(basename "$f")"
    fi
done

# 4. Handle legacy Git versions (< 2.35.0) for 'zdiff3' compatibility
if command -v git >/dev/null 2>&1; then
    GIT_VER=$(git --version | awk '{print $3}' | grep -oE '^[0-9]+\.[0-9]+')
    IFS='.' read -r major minor <<< "$GIT_VER"
    
    if [[ -n "$major" && -n "$minor" ]]; then
        if [ "$major" -lt 2 ] || { [ "$major" -eq 2 ] && [ "$minor" -lt 35 ]; }; then
            echo "Detected legacy Git version ($GIT_VER < 2.35) which does not support 'zdiff3'."
            
            # Ensure ~/.gitconfig.local has the fallback
            if [ ! -f "$HOME/.gitconfig.local" ] || ! grep -q "conflictstyle" "$HOME/.gitconfig.local" 2>/dev/null; then
                echo -e "\n[merge]\n\tconflictstyle = diff3" >> "$HOME/.gitconfig.local"
                echo "Added legacy 'conflictstyle = diff3' fallback to ~/.gitconfig.local"
            else
                echo "~/.gitconfig.local already configured."
            fi
        fi
    fi
fi

# 5. Install missing plugins and tools (TPM, fonts, fzf-git.sh, forgit, ranger_devicons)
echo "Installing shell plugins and fonts..."
IS_WINDOWS=false
[[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]] && IS_WINDOWS=true

if ! $IS_WINDOWS; then
    # Install vim-plug if missing
    if [ ! -f "$HOME/.vim/autoload/plug.vim" ]; then
        echo "Installing vim-plug for Vim..."
        curl -fLo "$HOME/.vim/autoload/plug.vim" --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    fi

    if [ ! -f "$HOME/.local/share/nvim/site/autoload/plug.vim" ]; then
        echo "Installing vim-plug for Neovim..."
        curl -fLo "$HOME/.local/share/nvim/site/autoload/plug.vim" --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    fi

    # Install TPM (Tmux Plugin Manager) if missing
    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
        echo "Installing TPM for Tmux..."
        git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
    fi
fi

if $IS_WINDOWS; then
    echo "Creating directory junctions for Git Bash Vim compatibility..."
    mkdir -p "$HOME/.vim"
    if [ ! -d "$HOME/.vim/autoload" ]; then
        cmd //c mklink //J "$(cygpath -w "$HOME/.vim/autoload")" "$(cygpath -w "$HOME/vimfiles/autoload")"
    fi
    if [ ! -d "$HOME/.vim/plugged" ]; then
        cmd //c mklink //J "$(cygpath -w "$HOME/.vim/plugged")" "$(cygpath -w "$HOME/vimfiles/plugged")"
    fi
fi

# Install Hack Nerd Font variations if missing
if [[ "$OSTYPE" == darwin* ]]; then
    if [ ! -f "$HOME/Library/Fonts/HackNerdFont-Regular.ttf" ] && \
       [ ! -f "$HOME/Library/Fonts/Hack Nerd Font Complete.ttf" ]; then
        if command -v brew >/dev/null 2>&1; then
            echo "Installing Hack Nerd Font via Homebrew..."
            brew install --cask font-hack-nerd-font
        fi
    fi
elif [[ "$OSTYPE" == linux* ]]; then
    if [ ! -f "$HOME/.local/share/fonts/HackNerdFont-Regular.ttf" ]; then
        echo "Installing all Hack Nerd Font variations..."
        mkdir -p "$HOME/.local/share/fonts"
        BASE_URL="https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/Hack"
        for style in "" "Mono" "Propo"; do
            for weight in "Regular" "Bold" "Italic" "BoldItalic"; do
                FILE="HackNerdFont${style}-${weight}.ttf"
                curl -sfLo "$HOME/.local/share/fonts/$FILE" "$BASE_URL/${weight}/$FILE"
            done
        done
        command -v fc-cache >/dev/null 2>&1 && fc-cache -f "$HOME/.local/share/fonts"
    fi
fi

PLUGINS_DIR="$HOME/.local/share"
mkdir -p "$PLUGINS_DIR"

install_plugin() {
    local repo=$1
    local name
    name=$(basename "$repo")
    local dir="$PLUGINS_DIR/$name"
    if [ ! -d "$dir" ]; then
        echo "Installing $repo..."
        git clone --depth 1 "https://github.com/$repo.git" "$dir"
    fi
}

install_plugin "junegunn/fzf-git.sh"
install_plugin "wfxr/forgit"

# Ranger Plugins
if ! $IS_WINDOWS; then
    RANGER_PLUGIN_DIR="$HOME/.config/ranger/plugins"
    if [ ! -d "$RANGER_PLUGIN_DIR/ranger_devicons" ]; then
        echo "Installing ranger_devicons..."
        mkdir -p "$RANGER_PLUGIN_DIR"
        git clone --depth 1 https://github.com/alexanderjeurissen/ranger_devicons "$RANGER_PLUGIN_DIR/ranger_devicons"
    fi
fi

echo "Deployment complete! Please restart your shell or run 'source ~/.bashrc'."
