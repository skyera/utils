#!/bin/bash
# deploy.sh - Copy configuration files to $HOME

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Create necessary directories
mkdir -p ~/.config/ranger ~/.config/lf ~/.config/git ~/.config/yazi ~/.config/nvim ~/bin

# 2. Helper function to copy
deploy_file() {
    local src="$1"
    local dest="$2"
    
    if [ ! -f "$src" ]; then
        echo "Warning: Source $src does not exist. Skipping."
        return
    fi

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

deploy_file "$REPO_DIR/myvimrc"    "$HOME/.vimrc"
deploy_file "$REPO_DIR/myvimrc"    "$HOME/.config/nvim/init.vim"
deploy_file "$REPO_DIR/.tigrc"      "$HOME/.tigrc"
deploy_file "$REPO_DIR/.tmux.conf" "$HOME/.tmux.conf"
deploy_file "$REPO_DIR/.ripgreprc" "$HOME/.ripgreprc"

# Config directories
deploy_file "$REPO_DIR/.config/ranger/rc.conf"      "$HOME/.config/ranger/rc.conf"
deploy_file "$REPO_DIR/.config/ranger/commands.py"  "$HOME/.config/ranger/commands.py"
deploy_file "$REPO_DIR/.config/lf/lfrc"             "$HOME/.config/lf/lfrc"
deploy_file "$REPO_DIR/.config/lf/icons"            "$HOME/.config/lf/icons"
deploy_file "$REPO_DIR/.config/git/ignore"          "$HOME/.config/git/ignore"

# Yazi configuration
echo "Deploying Yazi configuration..."
deploy_file "$REPO_DIR/yazi/theme.toml"             "$HOME/.config/yazi/theme.toml"
# Note: yazi_windows.toml is present but usually yazi expects yazi.toml on Linux
if [ -f "$REPO_DIR/yazi/yazi.toml" ]; then
    deploy_file "$REPO_DIR/yazi/yazi.toml"          "$HOME/.config/yazi/yazi.toml"
fi

# Binaries
echo "Deploying binaries to ~/bin/..."
for f in "$REPO_DIR/bin/"*; do
    if [ -f "$f" ]; then
        deploy_file "$f" "$HOME/bin/$(basename "$f")"
        chmod +x "$HOME/bin/$(basename "$f")"
    fi
done

echo "Deployment complete! Please restart your shell or run 'source ~/.bashrc'."
