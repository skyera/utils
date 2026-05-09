#!/usr/bin/env python3
"""
deploy_gui.py - Tkinter GUI for deploying configuration files
"""

import tkinter as tk
from tkinter import ttk, scrolledtext, messagebox
import os
import shutil
import subprocess
import platform


class DeployGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("Dotfiles Deployer")
        self.root.geometry("600x700")
        
        self.repo_dir = os.path.dirname(os.path.abspath(__file__))
        self.home_dir = os.path.expanduser("~")
        
        self.setup_ui()
    
    def setup_ui(self):
        # Main frame
        main_frame = ttk.Frame(self.root, padding="10")
        main_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # Title
        title_label = ttk.Label(
            main_frame,
            text="Dotfiles Deployment",
            font=("Helvetica", 16, "bold")
        )
        title_label.grid(row=0, column=0, columnspan=2, pady=(0, 15))
        
        # Neovim configuration choice
        nvim_frame = ttk.LabelFrame(main_frame, text="Neovim Configuration", padding="10")
        nvim_frame.grid(row=1, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=5)
        
        self.nvim_choice = tk.StringVar(value="lua")
        ttk.Radiobutton(
            nvim_frame,
            text="Lua (Neovim native)",
            variable=self.nvim_choice,
            value="lua"
        ).grid(row=0, column=0, sticky=tk.W)
        ttk.Radiobutton(
            nvim_frame,
            text="Vimscript (compatible)",
            variable=self.nvim_choice,
            value="vim"
        ).grid(row=1, column=0, sticky=tk.W)
        
        # Component selection
        comp_frame = ttk.LabelFrame(main_frame, text="Components to Deploy", padding="10")
        comp_frame.grid(row=2, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=5)
        
        self.components = {
            "bash": tk.BooleanVar(value=True),
            "vim": tk.BooleanVar(value=True),
            "nvim": tk.BooleanVar(value=True),
            "git": tk.BooleanVar(value=True),
            "tmux": tk.BooleanVar(value=True),
            "ranger": tk.BooleanVar(value=True),
            "lf": tk.BooleanVar(value=True),
            "yazi": tk.BooleanVar(value=True),
            "vifm": tk.BooleanVar(value=True),
            "gdb": tk.BooleanVar(value=True),
            "ripgrep": tk.BooleanVar(value=True),
            "binaries": tk.BooleanVar(value=True),
        }
        
        component_labels = [
            ("bash", "Bash/Zsh configuration"),
            ("vim", "Vim configuration"),
            ("nvim", "Neovim configuration"),
            ("git", "Git configuration"),
            ("tmux", "Tmux configuration"),
            ("ranger", "Ranger file manager"),
            ("lf", "LF file manager"),
            ("yazi", "Yazi file manager"),
            ("vifm", "Vifm file manager"),
            ("gdb", "GDB configuration"),
            ("ripgrep", "Ripgrep configuration"),
            ("binaries", "Binary scripts"),
        ]
        
        for i, (key, label) in enumerate(component_labels):
            row = i // 2
            col = (i % 2) * 2
            ttk.Checkbutton(
                comp_frame,
                text=label,
                variable=self.components[key]
            ).grid(row=row, column=col, sticky=tk.W, padx=5, pady=2)
        
        # Options
        opts_frame = ttk.LabelFrame(main_frame, text="Options", padding="10")
        opts_frame.grid(row=3, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=5)
        
        self.backup = tk.BooleanVar(value=True)
        ttk.Checkbutton(
            opts_frame,
            text="Backup existing files",
            variable=self.backup
        ).grid(row=0, column=0, sticky=tk.W)
        
        # Deploy button
        deploy_btn = ttk.Button(
            main_frame,
            text="Deploy",
            command=self.deploy
        )
        deploy_btn.grid(row=4, column=0, columnspan=2, pady=15)
        
        # Progress bar
        self.progress = ttk.Progressbar(
            main_frame,
            mode='determinate',
            length=560
        )
        self.progress.grid(row=5, column=0, columnspan=2, pady=5)
        
        # Log output
        log_frame = ttk.LabelFrame(main_frame, text="Log Output", padding="10")
        log_frame.grid(row=6, column=0, columnspan=2, sticky=(tk.W, tk.E, tk.N, tk.S), pady=5)
        
        self.log_text = scrolledtext.ScrolledText(
            log_frame,
            height=10,
            width=70,
            state='disabled'
        )
        self.log_text.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # Configure grid weights
        main_frame.columnconfigure(0, weight=1)
        main_frame.rowconfigure(6, weight=1)
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(0, weight=1)
    
    def log(self, message):
        """Add message to log window"""
        self.log_text.config(state='normal')
        self.log_text.insert(tk.END, message + "\n")
        self.log_text.see(tk.END)
        self.log_text.config(state='disabled')
        self.root.update()
    
    def deploy_file(self, src, dest):
        """Deploy a single file with backup option"""
        if not os.path.exists(src):
            self.log(f"Warning: Source {src} does not exist. Skipping.")
            return False
        
        # Create destination directory if needed
        dest_dir = os.path.dirname(dest)
        if dest_dir and not os.path.exists(dest_dir):
            os.makedirs(dest_dir)
        
        # Check if file needs updating
        if os.path.exists(dest):
            if self._files_equal(src, dest):
                self.log(f"Skipping {dest} (already up to date)")
                return True
            
            if self.backup.get():
                backup_path = dest + ".bak"
                self.log(f"Backing up {dest} to {backup_path}")
                shutil.copy2(dest, backup_path)
        
        shutil.copy2(src, dest)
        self.log(f"Deployed {dest}")
        return True
    
    def _files_equal(self, file1, file2):
        """Check if two files are equal"""
        try:
            with open(file1, 'rb') as f1, open(file2, 'rb') as f2:
                return f1.read() == f2.read()
        except:
            return False
    
    def deploy(self):
        """Execute deployment"""
        self.log_text.config(state='normal')
        self.log_text.delete(1.0, tk.END)
        self.log_text.config(state='disabled')
        
        self.progress['value'] = 0
        total_steps = sum(1 for v in self.components.values() if v.get())
        current_step = 0
        
        try:
            # Bash configuration
            if self.components["bash"].get():
                self.log("Deploying Bash configuration...")
                self.deploy_file(
                    os.path.join(self.repo_dir, "mybashrc"),
                    os.path.join(self.home_dir, ".mybashrc")
                )
                
                # Add sourcing line to .bashrc
                bashrc_path = os.path.join(self.home_dir, ".bashrc")
                bashrc_line = "[ -f ~/.mybashrc ] && . ~/.mybashrc"
                if os.path.exists(bashrc_path):
                    with open(bashrc_path, 'r') as f:
                        if bashrc_line not in f.read():
                            self.log(f"Adding sourcing line to ~/.bashrc")
                            with open(bashrc_path, 'a') as f:
                                f.write(f"\n# Source personal aliases and functions\n{bashrc_line}\n")
                
                # Add to .zshrc on macOS
                if platform.system() == "Darwin":
                    zshrc_path = os.path.join(self.home_dir, ".zshrc")
                    if os.path.exists(zshrc_path):
                        with open(zshrc_path, 'r') as f:
                            if bashrc_line not in f.read():
                                self.log(f"Adding sourcing line to ~/.zshrc")
                                with open(zshrc_path, 'a') as f:
                                    f.write(f"\n# Source personal aliases and functions\n{bashrc_line}\n")
                
                current_step += 1
                self.progress['value'] = (current_step / total_steps) * 100
            
            # Vim configuration
            if self.components["vim"].get():
                self.log("Deploying Vim configuration...")
                self.deploy_file(
                    os.path.join(self.repo_dir, "myvimrc"),
                    os.path.join(self.home_dir, ".vimrc")
                )
                current_step += 1
                self.progress['value'] = (current_step / total_steps) * 100
            
            # Neovim configuration
            if self.components["nvim"].get():
                self.log(f"Deploying Neovim ({self.nvim_choice.get()}) configuration...")
                nvim_config_dir = os.path.join(self.home_dir, ".config", "nvim")
                
                if self.nvim_choice.get() == "lua":
                    src_nvim_dir = os.path.join(self.repo_dir, ".config", "nvim")
                    if os.path.exists(src_nvim_dir):
                        if not os.path.exists(nvim_config_dir):
                            os.makedirs(nvim_config_dir)
                        
                        # Remove init.vim if it exists
                        init_vim = os.path.join(nvim_config_dir, "init.vim")
                        if os.path.exists(init_vim):
                            os.remove(init_vim)
                        
                        # Copy Lua config
                        for item in os.listdir(src_nvim_dir):
                            src = os.path.join(src_nvim_dir, item)
                            dest = os.path.join(nvim_config_dir, item)
                            if os.path.isdir(src):
                                if os.path.exists(dest):
                                    shutil.rmtree(dest)
                                shutil.copytree(src, dest)
                            else:
                                shutil.copy2(src, dest)
                        
                        self.log(f"Deployed Neovim configuration to {nvim_config_dir}")
                else:
                    # Vimscript mode
                    if os.path.exists(nvim_config_dir):
                        lua_dir = os.path.join(nvim_config_dir, "lua")
                        if os.path.exists(lua_dir):
                            shutil.rmtree(lua_dir)
                        
                        init_lua = os.path.join(nvim_config_dir, "init.lua")
                        if os.path.exists(init_lua):
                            os.remove(init_lua)
                    
                    self.deploy_file(
                        os.path.join(self.repo_dir, "myvimrc"),
                        os.path.join(nvim_config_dir, "init.vim")
                    )
                
                current_step += 1
                self.progress['value'] = (current_step / total_steps) * 100
            
            # Git configuration
            if self.components["git"].get():
                self.log("Deploying Git configuration...")
                self.deploy_file(
                    os.path.join(self.repo_dir, ".gitconfig"),
                    os.path.join(self.home_dir, ".gitconfig")
                )
                current_step += 1
                self.progress['value'] = (current_step / total_steps) * 100
            
            # Tmux configuration
            if self.components["tmux"].get():
                self.log("Deploying Tmux configuration...")
                self.deploy_file(
                    os.path.join(self.repo_dir, ".tmux.conf"),
                    os.path.join(self.home_dir, ".tmux.conf")
                )
                current_step += 1
                self.progress['value'] = (current_step / total_steps) * 100
            
            # Ranger configuration
            if self.components["ranger"].get():
                self.log("Deploying Ranger configuration...")
                ranger_dir = os.path.join(self.home_dir, ".config", "ranger")
                src_ranger_dir = os.path.join(self.repo_dir, ".config", "ranger")
                
                if os.path.exists(src_ranger_dir):
                    for file in ["rc.conf", "commands.py", "scope.sh"]:
                        self.deploy_file(
                            os.path.join(src_ranger_dir, file),
                            os.path.join(ranger_dir, file)
                        )
                    
                    # Copy colorschemes
                    src_colors = os.path.join(src_ranger_dir, "colorschemes")
                    if os.path.exists(src_colors):
                        dest_colors = os.path.join(ranger_dir, "colorschemes")
                        if not os.path.exists(dest_colors):
                            os.makedirs(dest_colors)
                        for item in os.listdir(src_colors):
                            shutil.copy2(
                                os.path.join(src_colors, item),
                                os.path.join(dest_colors, item)
                            )
                    
                    # Make scope.sh executable
                    scope_sh = os.path.join(ranger_dir, "scope.sh")
                    if os.path.exists(scope_sh):
                        os.chmod(scope_sh, 0o755)
                
                current_step += 1
                self.progress['value'] = (current_step / total_steps) * 100
            
            # LF configuration
            if self.components["lf"].get():
                self.log("Deploying LF configuration...")
                lf_dir = os.path.join(self.home_dir, ".config", "lf")
                src_lf_dir = os.path.join(self.repo_dir, ".config", "lf")
                
                if os.path.exists(src_lf_dir):
                    for file in ["lfrc", "icons", "colors"]:
                        self.deploy_file(
                            os.path.join(src_lf_dir, file),
                            os.path.join(lf_dir, file)
                        )
                
                current_step += 1
                self.progress['value'] = (current_step / total_steps) * 100
            
            # Yazi configuration
            if self.components["yazi"].get():
                self.log("Deploying Yazi configuration...")
                yazi_dir = os.path.join(self.home_dir, ".config", "yazi")
                src_yazi_dir = os.path.join(self.repo_dir, ".config", "yazi")
                
                if os.path.exists(src_yazi_dir):
                    for file in ["theme.toml", "keymap.toml", "yazi.toml"]:
                        src_file = os.path.join(src_yazi_dir, file)
                        if os.path.exists(src_file):
                            self.deploy_file(
                                src_file,
                                os.path.join(yazi_dir, file)
                            )
                
                current_step += 1
                self.progress['value'] = (current_step / total_steps) * 100
            
            # Vifm configuration
            if self.components["vifm"].get():
                self.log("Deploying Vifm configuration...")
                self.deploy_file(
                    os.path.join(self.repo_dir, ".vifm", "vifmrc"),
                    os.path.join(self.home_dir, ".vifm", "vifmrc")
                )
                current_step += 1
                self.progress['value'] = (current_step / total_steps) * 100
            
            # GDB configuration
            if self.components["gdb"].get():
                self.log("Deploying GDB configuration...")
                self.deploy_file(
                    os.path.join(self.repo_dir, ".gdbinit"),
                    os.path.join(self.home_dir, ".gdbinit")
                )
                current_step += 1
                self.progress['value'] = (current_step / total_steps) * 100
            
            # Ripgrep configuration
            if self.components["ripgrep"].get():
                self.log("Deploying Ripgrep configuration...")
                self.deploy_file(
                    os.path.join(self.repo_dir, ".ripgreprc"),
                    os.path.join(self.home_dir, ".ripgreprc")
                )
                current_step += 1
                self.progress['value'] = (current_step / total_steps) * 100
            
            # Binaries
            if self.components["binaries"].get():
                self.log("Deploying binaries to ~/bin/...")
                bin_dir = os.path.join(self.home_dir, "bin")
                if not os.path.exists(bin_dir):
                    os.makedirs(bin_dir)
                
                src_bin_dir = os.path.join(self.repo_dir, "bin")
                if os.path.exists(src_bin_dir):
                    for item in os.listdir(src_bin_dir):
                        src = os.path.join(src_bin_dir, item)
                        if os.path.isfile(src):
                            dest = os.path.join(bin_dir, item)
                            self.deploy_file(src, dest)
                            os.chmod(dest, 0o755)
                
                current_step += 1
                self.progress['value'] = (current_step / total_steps) * 100
            
            self.log("\nDeployment complete!")
            self.log("Please restart your shell or run 'source ~/.bashrc'.")
            messagebox.showinfo("Success", "Deployment completed successfully!")
            
        except Exception as e:
            self.log(f"Error during deployment: {str(e)}")
            messagebox.showerror("Error", f"Deployment failed: {str(e)}")


def main():
    root = tk.Tk()
    app = DeployGUI(root)
    root.mainloop()


if __name__ == "__main__":
    main()