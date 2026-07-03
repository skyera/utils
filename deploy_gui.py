#!/usr/bin/env python3
"""
deploy_gui.py - Cross-platform dotfiles deployment GUI with modern styling
"""

import tkinter as tk
from tkinter import ttk, messagebox
import os
import shutil
import filecmp
import platform
import difflib
from datetime import datetime


class DotfilesDeployGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("Dotfiles Deployer")
        self.root.geometry("1150x800")
        
        self.repo_dir = os.path.dirname(os.path.abspath(__file__))
        self.system = platform.system()
        
        # UI State
        self.backup_var = tk.BooleanVar(value=True)
        self.nvim_choice = tk.StringVar(value="lua")
        self.dark_mode = True  # Starts in Dark Mode by default
        
        # Store metadata for tree items
        self.source_metadata = {}
        self.dest_metadata = {}
        
        # File configurations
        self.file_configs = self._get_file_configs()
        
        self.setup_ui()
        self.apply_theme()
        self.refresh_file_lists()
    
    def _get_file_configs(self):
        """Unified configuration for all files and directories"""
        configs = [
            {
                "category": "Shell Configs",
                "items": [
                    {"src": "mybashrc", "dest": {"Unix": "~/.mybashrc", "Windows": "%USERPROFILE%/.mybashrc"}},
                ]
            },
            {
                "category": "Editor Configs",
                "items": [
                    {"src": "myvimrc", "dest": {"Unix": "~/.vimrc", "Windows": "%USERPROFILE%/_vimrc"}},
                    {"src": ".config/nvim", "dest": {"Unix": "~/.config/nvim", "Windows": "%LOCALAPPDATA%/nvim"}, "is_dir": True, "condition": "lua"},
                    {"src": "myvimrc", "dest": {"Unix": "~/.config/nvim/init.vim", "Windows": "%LOCALAPPDATA%/nvim/init.vim"}, "condition": "vim"},
                ]
            },
            {
                "category": "Dotfiles",
                "items": [
                    {"src": ".gitconfig", "dest": {"Unix": "~/.gitconfig", "Windows": "%USERPROFILE%/.gitconfig"}},
                    {"src": ".gitmessage", "dest": {"Unix": "~/.gitmessage", "Windows": "%USERPROFILE%/.gitmessage"}},
                    {"src": ".tmux.conf", "dest": {"Unix": "~/.tmux.conf"}},
                    {"src": ".tigrc", "dest": {"Unix": "~/.tigrc"}},
                    {"src": ".ripgreprc", "dest": {"Unix": "~/.ripgreprc", "Windows": "%USERPROFILE%/.ripgreprc"}},
                    {"src": ".gdbinit", "dest": {"Unix": "~/.gdbinit", "Windows": "%USERPROFILE%/.gdbinit"}},
                    {"src": ".wezterm.lua", "dest": {"Unix": "~/.wezterm.lua", "Windows": "%USERPROFILE%/.wezterm.lua"}},
                ]
            },
            {
                "category": "Tool Configs",
                "items": [
                    {"src": ".config/lf/lfrc", "dest": {"Unix": "~/.config/lf/lfrc"}},
                    {"src": ".config/lf/lfrc_windows", "dest": {"Windows": "%APPDATA%/lf/lfrc"}},
                    {"src": ".config/lf/icons", "dest": {"Unix": "~/.config/lf/icons", "Windows": "%APPDATA%/lf/icons"}},
                    {"src": ".config/lf/colors", "dest": {"Unix": "~/.config/lf/colors", "Windows": "%APPDATA%/lf/colors"}},
                    {"src": ".config/fd/ignore", "dest": {"Unix": "~/.config/fd/ignore", "Windows": "%APPDATA%/fd/ignore"}},
                    {"src": ".config/git/ignore", "dest": {"Unix": "~/.config/git/ignore", "Windows": "%USERPROFILE%/.config/git/ignore"}},
                    {"src": ".vifm/vifmrc", "dest": {"Unix": "~/.vifm/vifmrc", "Windows": "%APPDATA%/vifm/vifmrc"}},
                    {"src": ".config/yazi/theme.toml", "dest": {"Unix": "~/.config/yazi/theme.toml", "Windows": "%APPDATA%/yazi/config/theme.toml"}},
                    {"src": ".config/yazi/keymap.toml", "dest": {"Unix": "~/.config/yazi/keymap.toml", "Windows": "%APPDATA%/yazi/config/keymap.toml"}},
                    {"src": ".config/yazi/yazi.toml", "dest": {"Unix": "~/.config/yazi/yazi.toml", "Windows": "%APPDATA%/yazi/config/yazi.toml"}},
                    {"src": ".config/ranger/rc.conf", "dest": {"Unix": "~/.config/ranger/rc.conf", "Windows": "%APPDATA%/ranger/rc.conf"}},
                    {"src": ".config/ranger/commands.py", "dest": {"Unix": "~/.config/ranger/commands.py", "Windows": "%APPDATA%/ranger/commands.py"}},
                    {"src": ".config/ranger/scope.sh", "dest": {"Unix": "~/.config/ranger/scope.sh", "Windows": "%APPDATA%/ranger/scope.sh"}},
                    {"src": ".config/ranger/colorschemes", "dest": {"Unix": "~/.config/ranger/colorschemes", "Windows": "%APPDATA%/ranger/colorschemes"}, "is_dir": True},
                ]
            }
        ]
        
        # Add bin directory scripts dynamically
        bin_items = []
        bin_path = os.path.join(self.repo_dir, "bin")
        if os.path.exists(bin_path):
            for f in sorted(os.listdir(bin_path)):
                if os.path.isfile(os.path.join(bin_path, f)):
                    bin_items.append({
                        "src": f"bin/{f}",
                        "dest": {
                            "Unix": f"~/bin/{f}",
                            "Windows": f"C:/app/bin/{f}"
                        }
                    })
        
        if bin_items:
            configs.append({"category": "Binaries", "items": bin_items})
            
        return configs

    def resolve_path(self, path_config):
        """Resolve destination path based on OS and environment variables"""
        if isinstance(path_config, str):
            path = path_config
        else:
            # Check for specific OS first, then fallback to Unix/Windows categories
            os_name = self.system
            if os_name in path_config:
                path = path_config[os_name]
            elif os_name in ["Linux", "Darwin"] and "Unix" in path_config:
                path = path_config["Unix"]
            elif os_name == "Windows" and "Windows" in path_config:
                path = path_config["Windows"]
            else:
                return None
        
        # Expand ~ and environment variables
        path = os.path.expanduser(path)
        if self.system == "Windows":
            path = os.path.expandvars(path)
        else:
            path = os.path.expandvars(path)
            
        return os.path.abspath(path)

    def setup_ui(self):
        # Header section
        self.header_frame = tk.Frame(self.root, height=65)
        self.header_frame.pack(fill=tk.X)
        self.header_frame.pack_propagate(False)
        
        self.header_title = tk.Label(self.header_frame, text="🛡️ Dotfiles Deployer", font=("Arial", 16, "bold"))
        self.header_title.pack(side=tk.LEFT, padx=20)
        
        system_info = f"💻 {self.system} | 🏠 {os.path.expanduser('~')}"
        self.header_sys_info = tk.Label(self.header_frame, text=system_info, font=("Arial", 10))
        self.header_sys_info.pack(side=tk.RIGHT, padx=20)
        
        # Top toolbar
        toolbar = ttk.Frame(self.root, padding="10")
        toolbar.pack(fill=tk.X)
        
        btn_refresh = ttk.Button(toolbar, text="🔄 Refresh", command=self.refresh_file_lists)
        btn_refresh.pack(side=tk.LEFT, padx=5)
        
        btn_sel = ttk.Button(toolbar, text="🚀 Deploy Selected", command=self.deploy_selected)
        btn_sel.pack(side=tk.LEFT, padx=5)
        
        btn_all = ttk.Button(toolbar, text="🔥 Deploy All", command=self.deploy_all)
        btn_all.pack(side=tk.LEFT, padx=5)
        
        ttk.Separator(toolbar, orient=tk.VERTICAL).pack(side=tk.LEFT, padx=15, fill=tk.Y)
        
        chk_bak = ttk.Checkbutton(toolbar, text="💾 Auto Backup (.bak)", variable=self.backup_var)
        chk_bak.pack(side=tk.LEFT, padx=5)
        
        ttk.Separator(toolbar, orient=tk.VERTICAL).pack(side=tk.LEFT, padx=15, fill=tk.Y)
        
        ttk.Label(toolbar, text="⚙️ Neovim: ", font=("Arial", 9, "bold")).pack(side=tk.LEFT, padx=5)
        ttk.Radiobutton(toolbar, text="Lua", variable=self.nvim_choice, value="lua", command=self.refresh_file_lists).pack(side=tk.LEFT)
        ttk.Radiobutton(toolbar, text="Vimscript", variable=self.nvim_choice, value="vim", command=self.refresh_file_lists).pack(side=tk.LEFT)
        
        # Theme toggle button
        self.btn_theme = ttk.Button(toolbar, text="🌙 Dark", command=self.toggle_theme)
        self.btn_theme.pack(side=tk.RIGHT, padx=5)
        
        # Main content area
        main_content = ttk.Frame(self.root, padding="5")
        main_content.pack(fill=tk.BOTH, expand=True)
        
        # Outer vertical paned window
        self.v_paned = ttk.PanedWindow(main_content, orient=tk.VERTICAL)
        self.v_paned.pack(fill=tk.BOTH, expand=True)
        
        # Top paned window (Horizontal)
        self.paned = ttk.PanedWindow(self.v_paned, orient=tk.HORIZONTAL)
        self.v_paned.add(self.paned, weight=3)
        
        # Left pane - Source
        left_frame = ttk.LabelFrame(self.paned, text=" 📂 Source (Repository) ", padding="5")
        self.paned.add(left_frame, weight=1)
        
        self.source_tree = ttk.Treeview(left_frame, columns=("status", "dest"), show="tree headings")
        self.source_tree.heading("#0", text="File/Directory")
        self.source_tree.heading("status", text="Status")
        self.source_tree.heading("dest", text="Destination Path")
        self.source_tree.column("#0", width=220)
        self.source_tree.column("status", width=110, anchor=tk.CENTER)
        self.source_tree.column("dest", width=380)
        self.source_tree.pack(fill=tk.BOTH, expand=True)
        
        s_scroll = ttk.Scrollbar(left_frame, orient=tk.VERTICAL, command=self.source_tree.yview)
        s_scroll.pack(side=tk.RIGHT, fill=tk.Y)
        self.source_tree.configure(yscrollcommand=s_scroll.set)
        
        # Right pane - Destination
        right_frame = ttk.LabelFrame(self.paned, text=" 🏠 Destination (System) ", padding="5")
        self.paned.add(right_frame, weight=1)
        
        self.dest_tree = ttk.Treeview(right_frame, columns=("status", "src"), show="tree headings")
        self.dest_tree.heading("#0", text="File/Directory")
        self.dest_tree.heading("status", text="Status")
        self.dest_tree.heading("src", text="Source Path")
        self.dest_tree.column("#0", width=220)
        self.dest_tree.column("status", width=110, anchor=tk.CENTER)
        self.dest_tree.column("src", width=380)
        self.dest_tree.pack(fill=tk.BOTH, expand=True)
        
        d_scroll = ttk.Scrollbar(right_frame, orient=tk.VERTICAL, command=self.dest_tree.yview)
        d_scroll.pack(side=tk.RIGHT, fill=tk.Y)
        self.dest_tree.configure(yscrollcommand=d_scroll.set)

        # Bottom pane - Diff View
        diff_frame = ttk.LabelFrame(self.v_paned, text=" 🔍 Difference (Source vs Destination) ", padding="5")
        self.v_paned.add(diff_frame, weight=2)
        
        self.diff_text = tk.Text(diff_frame, wrap=tk.NONE, height=10,
                                 font=("Consolas" if self.system == "Windows" else "Monospace", 10))
        
        d_scroll_y = ttk.Scrollbar(diff_frame, orient=tk.VERTICAL, command=self.diff_text.yview)
        d_scroll_x = ttk.Scrollbar(diff_frame, orient=tk.HORIZONTAL, command=self.diff_text.xview)
        self.diff_text.configure(yscrollcommand=d_scroll_y.set, xscrollcommand=d_scroll_x.set)
        
        d_scroll_y.pack(side=tk.RIGHT, fill=tk.Y)
        d_scroll_x.pack(side=tk.BOTTOM, fill=tk.X)
        self.diff_text.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        
        # Status bar
        self.status_bar = tk.Label(self.root, text="Ready", relief=tk.SUNKEN, anchor=tk.W, 
                                   padx=10, pady=5, font=("Arial", 9))
        self.status_bar.pack(fill=tk.X)
        
        # Bind events
        self.source_tree.bind("<Double-1>", self.on_source_double_click)
        self.source_tree.bind("<Button-3>", self.on_source_right_click)
        self.source_tree.bind("<<TreeviewSelect>>", self.on_tree_select)
        
        self.dest_tree.bind("<Button-3>", self.on_dest_right_click)
        self.dest_tree.bind("<<TreeviewSelect>>", self.on_tree_select)

    def apply_theme(self):
        """Apply theme colors and styles based on the active mode (Light or Dark)"""
        style = ttk.Style()
        
        # Color Palettes
        if self.dark_mode:
            # Charcoal Dark Theme
            self.colors = {
                "bg": "#1e1e24",          # Deep Charcoal window background
                "surface": "#2d3142",     # Dark Slate container background
                "fg": "#eceff1",          # Cool Off-White text
                "fg_sub": "#90a4ae",      # Muted Blue-Gray
                "accent_green": "#4caf50",# Bright emerald green
                "accent_orange": "#ff9800",# Soft warm orange
                "accent_red": "#ef5350",   # Coral red
                "accent_blue": "#29b6f6",  # Cool cyan/blue
                "select_bg": "#3e4a5d",   # Dark Slate active selection
                "select_fg": "#ffffff",
                "stripe_even": "#242835", # Subtle row zebra color
                "stripe_odd": "#2d3142",
                "border": "#3a3f58",
                "text_bg": "#15171e",     # Even darker text background for Diff
                "text_insert": "#ffffff", # White caret
            }
        else:
            # Elegant Light Theme
            self.colors = {
                "bg": "#f4f6f8",          # Warm Light-Gray window background
                "surface": "#ffffff",     # Crisp White container background
                "fg": "#1a1f2c",          # Deep Slate-Black text
                "fg_sub": "#627d98",      # Slate Gray
                "accent_green": "#2e7d32",# Rich Forest Green
                "accent_orange": "#e65100",# Deep Amber Orange
                "accent_red": "#c62828",   # Deep Ruby Red
                "accent_blue": "#1565c0",  # Strong Royal Blue
                "select_bg": "#dbeafe",   # Sky Blue active selection
                "select_fg": "#1e3a8a",
                "stripe_even": "#f8fafc", # Subtle row zebra color
                "stripe_odd": "#ffffff",
                "border": "#cfd8dc",
                "text_bg": "#ffffff",     # White background for Diff
                "text_insert": "#000000", # Black caret
            }

        # Apply root background
        self.root.configure(bg=self.colors["bg"])
        
        # Define ttk element styles
        style.theme_use("clam")
        
        style.configure(".",
            background=self.colors["bg"],
            foreground=self.colors["fg"],
            font=("Segoe UI" if self.system == "Windows" else "Sans", 10),
            troughcolor=self.colors["bg"],
            bordercolor=self.colors["border"],
            darkcolor=self.colors["border"],
            lightcolor=self.colors["border"],
        )
        
        # Frames
        style.configure("TFrame", background=self.colors["bg"])
        style.configure("TLabelframe", background=self.colors["bg"], foreground=self.colors["fg"], bordercolor=self.colors["border"])
        style.configure("TLabelframe.Label", background=self.colors["bg"], foreground=self.colors["accent_blue"], font=("Segoe UI" if self.system == "Windows" else "Sans", 10, "bold"))
        
        # Buttons
        style.configure("TButton",
            background=self.colors["surface"],
            foreground=self.colors["fg"],
            bordercolor=self.colors["border"],
            darkcolor=self.colors["border"],
            lightcolor=self.colors["border"],
            padding=6,
            relief="flat",
            font=("Segoe UI" if self.system == "Windows" else "Sans", 9, "bold")
        )
        style.map("TButton",
            background=[("active", self.colors["select_bg"]), ("pressed", self.colors["border"])],
            foreground=[("active", self.colors["select_fg"])],
        )
        
        # Checkbutton / Radiobutton
        style.configure("TCheckbutton", background=self.colors["bg"], foreground=self.colors["fg"])
        style.configure("TRadiobutton", background=self.colors["bg"], foreground=self.colors["fg"])
        
        # Paned Window
        style.configure("TPanedwindow", background=self.colors["bg"])
        
        # Treeview
        style.configure("Treeview",
            background=self.colors["surface"],
            fieldbackground=self.colors["surface"],
            foreground=self.colors["fg"],
            rowheight=26,
            font=("Segoe UI" if self.system == "Windows" else "Sans", 10),
            borderwidth=1,
            relief="flat"
        )
        style.map("Treeview",
            background=[("selected", self.colors["select_bg"])],
            foreground=[("selected", self.colors["select_fg"])],
        )
        
        style.configure("Treeview.Heading",
            background=self.colors["bg"],
            foreground=self.colors["fg"],
            font=("Segoe UI" if self.system == "Windows" else "Sans", 10, "bold"),
            borderwidth=1,
            relief="flat"
        )
        style.map("Treeview.Heading",
            background=[("active", self.colors["surface"])],
        )
        
        # Update Diff text widget colors
        self.diff_text.config(
            bg=self.colors["text_bg"],
            fg=self.colors["fg"],
            insertbackground=self.colors["text_insert"],
            selectbackground=self.colors["select_bg"],
            selectforeground=self.colors["select_fg"],
            highlightbackground=self.colors["border"],
            highlightcolor=self.colors["accent_blue"]
        )
        
        # Update header frame styles
        self.header_frame.configure(bg=self.colors["surface"])
        self.header_title.configure(bg=self.colors["surface"], fg=self.colors["accent_blue"])
        self.header_sys_info.configure(bg=self.colors["surface"], fg=self.colors["fg_sub"])
            
        # Update status bar background
        self.status_bar.configure(bg=self.colors["surface"], fg=self.colors["fg_sub"])
            
        # Update Treeview tags
        for tree in [self.source_tree, self.dest_tree]:
            tree.tag_configure("green", foreground=self.colors["accent_green"], font=("Arial", 9, "bold"))
            tree.tag_configure("orange", foreground=self.colors["accent_orange"], font=("Arial", 9, "bold"))
            tree.tag_configure("red", foreground=self.colors["accent_red"], font=("Arial", 9, "bold"))
            tree.tag_configure("gray", foreground=self.colors["fg_sub"])
            tree.tag_configure("even", background=self.colors["stripe_even"])
            tree.tag_configure("odd", background=self.colors["stripe_odd"])

        # Update Diff View text tags
        self.diff_text.tag_configure("diff_add", foreground=self.colors["accent_green"], background="#e8f8f5" if not self.dark_mode else "#162e24")
        self.diff_text.tag_configure("diff_sub", foreground=self.colors["accent_red"], background="#f9ebeb" if not self.dark_mode else "#351a1e")
        self.diff_text.tag_configure("diff_header", foreground=self.colors["accent_blue"], font=("Consolas" if self.system == "Windows" else "Monospace", 10, "bold"))
        self.diff_text.tag_configure("diff_orange", foreground=self.colors["accent_orange"])

        # Update theme toggle button text
        theme_icon = "☀️ Light" if self.dark_mode else "🌙 Dark"
        self.btn_theme.configure(text=theme_icon)

    def toggle_theme(self):
        """Toggle between Dark and Light mode themes"""
        self.dark_mode = not self.dark_mode
        self.apply_theme()
        self.refresh_file_lists()

    def is_binary_file(self, filepath):
        """Check if a file is binary by looking for null bytes in the first 2KB"""
        if not os.path.isfile(filepath):
            return False
        try:
            with open(filepath, 'rb') as f:
                chunk = f.read(2048)
                return b'\x00' in chunk
        except Exception:
            return True  # Treat as binary on read errors

    def get_file_sha256(self, filepath):
        """Compute the SHA-256 hash of a file"""
        import hashlib
        if not os.path.isfile(filepath):
            return None
        sha256 = hashlib.sha256()
        try:
            with open(filepath, 'rb') as f:
                while True:
                    data = f.read(65536)
                    if not data:
                        break
                    sha256.update(data)
            return sha256.hexdigest()
        except Exception:
            return "Error calculating hash"

    def get_sync_status(self, src, dest, is_dir=False):
        """Compare src and dest to get status with icons, handling broken symlinks safely"""
        if not os.path.lexists(src):
            return "❔ Missing Src", "gray"
        
        if not os.path.lexists(dest):
            return "❌ Missing", "red"
        
        try:
            if is_dir:
                return "✅ Exists", "green"
            else:
                if os.path.islink(dest):
                    # Destination is a symlink (could be valid or broken)
                    try:
                        target = os.readlink(dest)
                        target_abs = os.path.abspath(os.path.expanduser(target))
                        src_abs = os.path.abspath(src)
                        if target_abs == src_abs:
                            return "✅ Synced Link", "green"
                        else:
                            return "⚠️ Outdated Link", "orange"
                    except Exception:
                        return "🚫 Broken Link", "red"
                
                # Check for standard file comparison
                if filecmp.cmp(src, dest, shallow=False):
                    return "✅ Synced", "green"
                else:
                    return "⚠️ Outdated", "orange"
        except Exception:
            return "🚫 Error", "red"

    def on_tree_select(self, event):
        """Handle selection in either tree to show diff"""
        tree = event.widget
        selection = tree.selection()
        if not selection:
            return
            
        item_id = selection[0]
        metadata = self.source_metadata if tree == self.source_tree else self.dest_metadata
        
        if item_id in metadata:
            m = metadata[item_id]
            self.show_diff(m["src"], m["dest"], m["is_dir"])
        else:
            # Category selected
            self.diff_text.config(state=tk.NORMAL)
            self.diff_text.delete(1.0, tk.END)
            self.diff_text.config(state=tk.DISABLED)

    def show_diff(self, src, dest, is_dir=False):
        """Generate and display unified diff, directory summaries, or binary metadata differences"""
        self.diff_text.config(state=tk.NORMAL)
        self.diff_text.delete(1.0, tk.END)
        
        if is_dir:
            self.diff_text.insert(tk.END, f"📂 Directory Comparison Summary\n", "diff_header")
            self.diff_text.insert(tk.END, f"Source: {src}\n")
            self.diff_text.insert(tk.END, f"Destination: {dest}\n\n")
            
            if not os.path.lexists(dest):
                self.diff_text.insert(tk.END, "❌ Destination directory does not exist.\n", "diff_sub")
                self.diff_text.insert(tk.END, "\nFiles to be deployed:\n", "diff_header")
                for root_dir, _, files in os.walk(src):
                    for file in files:
                        full_path = os.path.join(root_dir, file)
                        rel_path = os.path.relpath(full_path, src)
                        self.diff_text.insert(tk.END, f"  + {rel_path}\n", "diff_add")
            else:
                # Both exist, compare them recursively
                src_files = {}
                dest_files = {}
                
                for root_dir, _, files in os.walk(src):
                    for file in files:
                        full_path = os.path.join(root_dir, file)
                        rel_path = os.path.relpath(full_path, src)
                        src_files[rel_path] = full_path
                        
                for root_dir, _, files in os.walk(dest):
                    for file in files:
                        full_path = os.path.join(root_dir, file)
                        rel_path = os.path.relpath(full_path, dest)
                        dest_files[rel_path] = full_path
                
                all_rel_paths = sorted(list(set(src_files.keys()) | set(dest_files.keys())))
                
                modified_files = []
                added_files = []
                removed_files = []
                synced_files = []
                
                for rel_path in all_rel_paths:
                    s_file = src_files.get(rel_path)
                    d_file = dest_files.get(rel_path)
                    
                    if s_file and not d_file:
                        added_files.append(rel_path)
                    elif not s_file and d_file:
                        removed_files.append(rel_path)
                    else:
                        if self.is_binary_file(s_file) or self.is_binary_file(d_file):
                            s_hash = self.get_file_sha256(s_file)
                            d_hash = self.get_file_sha256(d_file)
                            if s_hash == d_hash:
                                synced_files.append(rel_path)
                            else:
                                modified_files.append(rel_path)
                        else:
                            if filecmp.cmp(s_file, d_file, shallow=False):
                                synced_files.append(rel_path)
                            else:
                                modified_files.append(rel_path)
                
                # Render results in diff view
                if modified_files:
                    self.diff_text.insert(tk.END, "⚠️ Modified Files (Differing Content/Size):\n", "diff_header")
                    for f in modified_files:
                        self.diff_text.insert(tk.END, f"  ~ {f}\n", "diff_orange")
                    self.diff_text.insert(tk.END, "\n")
                    
                if added_files:
                    self.diff_text.insert(tk.END, "➕ New Files (In Repository only):\n", "diff_header")
                    for f in added_files:
                        self.diff_text.insert(tk.END, f"  + {f}\n", "diff_add")
                    self.diff_text.insert(tk.END, "\n")
                    
                if removed_files:
                    self.diff_text.insert(tk.END, "❌ Untracked Files (In System destination only):\n", "diff_header")
                    for f in removed_files:
                        self.diff_text.insert(tk.END, f"  - {f} (Will be removed on sync)\n", "diff_sub")
                    self.diff_text.insert(tk.END, "\n")
                    
                if synced_files:
                    self.diff_text.insert(tk.END, "✅ Synced Files:\n", "diff_header")
                    # Display count instead of a huge list to keep view readable
                    self.diff_text.insert(tk.END, f"  ({len(synced_files)} identical files synced successfully)\n", "diff_add")
                        
                if not modified_files and not added_files and not removed_files:
                    self.diff_text.insert(tk.END, "✨ All files in the directory are fully identical.", "diff_add")
                    
        elif not os.path.lexists(src):
            self.diff_text.insert(tk.END, f"Source file missing: {src}")
            
        elif self.is_binary_file(src) or (os.path.lexists(dest) and self.is_binary_file(dest)):
            # Binary Comparison Panel
            self.diff_text.insert(tk.END, "💾 Binary File Comparison (Metadata Only)\n\n", "diff_header")
            
            src_size = os.path.getsize(src) if os.path.isfile(src) else 0
            src_time = datetime.fromtimestamp(os.path.getmtime(src)).strftime('%Y-%m-%d %H:%M:%S') if os.path.isfile(src) else "N/A"
            src_hash = self.get_file_sha256(src)
            
            self.diff_text.insert(tk.END, f"Source (Repository):\n", "diff_header")
            self.diff_text.insert(tk.END, f"  Path: {src}\n")
            self.diff_text.insert(tk.END, f"  Size: {src_size:,} bytes\n")
            self.diff_text.insert(tk.END, f"  Modified: {src_time}\n")
            self.diff_text.insert(tk.END, f"  SHA-256: {src_hash}\n\n")
            
            if not os.path.lexists(dest):
                self.diff_text.insert(tk.END, "Destination (System):\n", "diff_header")
                self.diff_text.insert(tk.END, "  ❌ File does not exist at destination.\n", "diff_sub")
            else:
                dest_size = os.path.getsize(dest) if os.path.isfile(dest) else 0
                dest_time = datetime.fromtimestamp(os.path.getmtime(dest)).strftime('%Y-%m-%d %H:%M:%S') if os.path.isfile(dest) else "N/A"
                dest_hash = self.get_file_sha256(dest)
                
                self.diff_text.insert(tk.END, f"Destination (System):\n", "diff_header")
                self.diff_text.insert(tk.END, f"  Path: {dest}\n")
                self.diff_text.insert(tk.END, f"  Size: {dest_size:,} bytes\n")
                self.diff_text.insert(tk.END, f"  Modified: {dest_time}\n")
                self.diff_text.insert(tk.END, f"  SHA-256: {dest_hash}\n\n")
                
                if src_hash == dest_hash:
                    self.diff_text.insert(tk.END, "✨ Files are identical (matched hashes).", "diff_add")
                else:
                    self.diff_text.insert(tk.END, "⚠️ Files differ (hash or size mismatch).", "diff_sub")
                    
        elif not os.path.lexists(dest):
            self.diff_text.insert(tk.END, f"Destination file missing (New file):\n\n", "diff_orange")
            try:
                with open(src, 'r', encoding='utf-8', errors='replace') as f:
                    self.diff_text.insert(tk.END, f.read())
            except Exception as e:
                self.diff_text.insert(tk.END, f"Error reading source: {e}")
        else:
            try:
                with open(src, 'r', encoding='utf-8', errors='replace') as f1:
                    src_lines = f1.readlines()
                with open(dest, 'r', encoding='utf-8', errors='replace') as f2:
                    dest_lines = f2.readlines()
                
                diff = difflib.unified_diff(
                    dest_lines, src_lines, 
                    fromfile=f"System: {os.path.basename(dest)}", 
                    tofile=f"Repo: {os.path.basename(src)}",
                    lineterm=''
                )
                
                has_diff = False
                for line in diff:
                    has_diff = True
                    tag = None
                    if line.startswith('+'): tag = "diff_add"
                    elif line.startswith('-'): tag = "diff_sub"
                    elif line.startswith('@'): tag = "diff_header"
                    
                    self.diff_text.insert(tk.END, line + '\n', tag)
                
                if not has_diff:
                    self.diff_text.insert(tk.END, "✨ Files are identical.", "diff_add")
                    
            except Exception as e:
                self.diff_text.insert(tk.END, f"Error generating diff: {e}")
        
        self.diff_text.config(state=tk.DISABLED)

    def refresh_file_lists(self):
        """Refresh both treeviews based on current config and nvim choice"""
        for tree in [self.source_tree, self.dest_tree]:
            for item in tree.get_children():
                tree.delete(item)
        
        self.source_metadata.clear()
        self.dest_metadata.clear()
        
        total_items = 0
        
        for cat_config in self.file_configs:
            category = cat_config["category"]
            src_cat_id = self.source_tree.insert("", tk.END, text=category, open=True)
            dest_cat_id = self.dest_tree.insert("", tk.END, text=category, open=True)
            
            row_idx = 0
            for item in cat_config["items"]:
                if "condition" in item:
                    if item["condition"] != self.nvim_choice.get():
                        continue
                
                src_path = os.path.join(self.repo_dir, item["src"])
                dest_path = self.resolve_path(item["dest"])
                
                if not dest_path:
                    continue
                
                is_dir = item.get("is_dir", False)
                status, color = self.get_sync_status(src_path, dest_path, is_dir)
                
                stripe_tag = "even" if row_idx % 2 == 0 else "odd"
                
                # Source Tree
                sid = self.source_tree.insert(
                    src_cat_id, tk.END,
                    text=item["src"],
                    values=(status, dest_path),
                    tags=(color, stripe_tag)
                )
                self.source_metadata[sid] = {"src": src_path, "dest": dest_path, "is_dir": is_dir}
                
                # Dest Tree
                did = self.dest_tree.insert(
                    dest_cat_id, tk.END,
                    text=os.path.basename(dest_path),
                    values=(status, item["src"]),
                    tags=(color, stripe_tag)
                )
                self.dest_metadata[did] = {"src": src_path, "dest": dest_path, "is_dir": is_dir}
                
                total_items += 1
                row_idx += 1
        
        self.status_bar.config(text=f" 📋 Total items: {total_items} | System: {self.system} ")

    def _post_deploy_shell_config(self, dest):
        """Ensure ~/.mybashrc is sourced in ~/.bashrc (and ~/.zshrc on macOS)"""
        if os.path.basename(dest) != ".mybashrc" and os.path.basename(dest) != "mybashrc":
            return
        
        home = os.path.expanduser("~")
        sourcing_line = "[ -f ~/.mybashrc ] && . ~/.mybashrc"
        
        shell_configs = [os.path.join(home, ".bashrc")]
        if self.system == "Darwin":
            shell_configs.append(os.path.join(home, ".zshrc"))
            
        for config_path in shell_configs:
            if os.path.lexists(config_path):
                try:
                    with open(config_path, "r", encoding="utf-8", errors="replace") as f:
                        content = f.read()
                    
                    if sourcing_line not in content:
                        with open(config_path, "a", encoding="utf-8") as f:
                            f.write(f"\n# Source personal aliases and functions\n{sourcing_line}\n")
                        self.status_bar.config(text=f"Sourcing block appended to {os.path.basename(config_path)}")
                except Exception as e:
                    print(f"Error appending sourcing to {config_path}: {e}")

    def deploy_file(self, src, dest, is_dir=False):
        """Core deployment logic for single file or directory, handling symlinks and conflicts safely"""
        if not os.path.lexists(src):
            return False, f"Source not found: {src}"
        
        try:
            dest_dir = os.path.dirname(dest)
            if not os.path.lexists(dest_dir):
                os.makedirs(dest_dir)
            
            # Backup
            if self.backup_var.get() and os.path.lexists(dest):
                bak_path = dest + ".bak"
                
                # Clean up existing backup of same path
                if os.path.lexists(bak_path):
                    if os.path.islink(bak_path) or os.path.isfile(bak_path):
                        os.remove(bak_path)
                    elif os.path.isdir(bak_path):
                        shutil.rmtree(bak_path)
                        
                # Copy backup
                if os.path.islink(dest):
                    os.symlink(os.readlink(dest), bak_path)
                elif os.path.isdir(dest):
                    shutil.copytree(dest, bak_path)
                else:
                    shutil.copy2(dest, bak_path)
            
            # Handle Neovim conflicts specifically
            dest_basename = os.path.basename(dest)
            if "nvim" in dest.lower():
                if is_dir and dest_basename == "nvim":
                    init_vim_path = os.path.join(dest, "init.vim")
                    if os.path.lexists(init_vim_path):
                        os.remove(init_vim_path)
                elif dest_basename == "init.vim":
                    nvim_dir = os.path.dirname(dest)
                    init_lua_path = os.path.join(nvim_dir, "init.lua")
                    lua_dir_path = os.path.join(nvim_dir, "lua")
                    if os.path.lexists(init_lua_path):
                        os.remove(init_lua_path)
                    if os.path.lexists(lua_dir_path):
                        if os.path.islink(lua_dir_path):
                            os.remove(lua_dir_path)
                        else:
                            shutil.rmtree(lua_dir_path)
            
            # Deploy
            if is_dir:
                if os.path.lexists(dest):
                    if os.path.islink(dest) or os.path.isfile(dest):
                        os.remove(dest)
                    elif os.path.isdir(dest):
                        shutil.rmtree(dest)
                shutil.copytree(src, dest)
            else:
                if os.path.lexists(dest):
                    if os.path.islink(dest) or os.path.isfile(dest):
                        os.remove(dest)
                    elif os.path.isdir(dest):
                        shutil.rmtree(dest)
                shutil.copy2(src, dest)
                
                # Permissions
                if self.system != "Windows":
                    if "/bin/" in src or src.endswith(".sh"):
                        os.chmod(dest, 0o755)
            
            # Post-deployment sourcing hook for mybashrc
            if dest_basename == ".mybashrc" or dest_basename == "mybashrc":
                self._post_deploy_shell_config(dest)
            
            return True, f"Deployed to {dest}"
        except Exception as e:
            return False, str(e)

    def on_source_double_click(self, event):
        selection = self.source_tree.selection()
        if selection:
            item_id = selection[0]
            if item_id in self.source_metadata:
                m = self.source_metadata[item_id]
                success, msg = self.deploy_file(m["src"], m["dest"], m["is_dir"])
                if success:
                    self.refresh_file_lists()
                    self.status_bar.config(text=msg)
                else:
                    messagebox.showerror("Error", msg)

    def on_source_right_click(self, event):
        row_id = self.source_tree.identify_row(event.y)
        if row_id:
            self.source_tree.selection_set(row_id)
            self.source_tree.focus(row_id)
            
        selection = self.source_tree.selection()
        if not selection: return
        
        item_id = selection[0]
        menu = tk.Menu(self.root, tearoff=0)
        
        if item_id in self.source_metadata:
            m = self.source_metadata[item_id]
            menu.add_command(label="Deploy Selected", command=lambda: self.deploy_source_item(item_id))
            menu.add_command(label="Open Source", command=lambda: self.open_path(m["src"]))
            menu.add_command(label="Open Destination", command=lambda: self.open_path(os.path.dirname(m["dest"])))
        else:
            menu.add_command(label="Deploy Category", command=lambda: self.deploy_category(item_id))
            
        menu.post(event.x_root, event.y_root)

    def on_dest_right_click(self, event):
        row_id = self.dest_tree.identify_row(event.y)
        if row_id:
            self.dest_tree.selection_set(row_id)
            self.dest_tree.focus(row_id)
            
        selection = self.dest_tree.selection()
        if not selection: return
        
        item_id = selection[0]
        if item_id not in self.dest_metadata: return
        
        m = self.dest_metadata[item_id]
        menu = tk.Menu(self.root, tearoff=0)
        menu.add_command(label="Open File", command=lambda: self.open_path(m["dest"]))
        menu.add_command(label="Open Location", command=lambda: self.open_path(os.path.dirname(m["dest"])))
        
        bak_path = m["dest"] + ".bak"
        if os.path.lexists(bak_path):
            menu.add_separator()
            menu.add_command(label="Restore from .bak", command=lambda: self.restore_bak(m))
            
        menu.post(event.x_root, event.y_root)

    def deploy_source_item(self, item_id):
        m = self.source_metadata[item_id]
        success, msg = self.deploy_file(m["src"], m["dest"], m["is_dir"])
        self.refresh_file_lists()
        if not success: messagebox.showerror("Error", msg)

    def deploy_category(self, cat_id):
        children = self.source_tree.get_children(cat_id)
        count = 0
        for child in children:
            if child in self.source_metadata:
                m = self.source_metadata[child]
                success, _ = self.deploy_file(m["src"], m["dest"], m["is_dir"])
                if success: count += 1
        self.refresh_file_lists()
        self.status_bar.config(text=f"Deployed {count} items in category")

    def deploy_selected(self):
        selection = self.source_tree.selection()
        count = 0
        for item_id in selection:
            if item_id in self.source_metadata:
                m = self.source_metadata[item_id]
                success, _ = self.deploy_file(m["src"], m["dest"], m["is_dir"])
                if success: count += 1
        self.refresh_file_lists()
        messagebox.showinfo("Done", f"Deployed {count} items")

    def deploy_all(self):
        if not messagebox.askyesno("Confirm", "Deploy all items in the current view?"):
            return
        
        count = 0
        for cat_id in self.source_tree.get_children(""):
            for child in self.source_tree.get_children(cat_id):
                if child in self.source_metadata:
                    m = self.source_metadata[child]
                    success, _ = self.deploy_file(m["src"], m["dest"], m["is_dir"])
                    if success: count += 1
        self.refresh_file_lists()
        messagebox.showinfo("Done", f"Deployed {count} items")

    def restore_bak(self, m):
        bak_path = m["dest"] + ".bak"
        if not messagebox.askyesno("Confirm", f"Restore {m['dest']} from backup?"):
            return
        
        try:
            if m["is_dir"]:
                if os.path.lexists(m["dest"]):
                    if os.path.islink(m["dest"]) or os.path.isfile(m["dest"]):
                        os.remove(m["dest"])
                    else:
                        shutil.rmtree(m["dest"])
                shutil.copytree(bak_path, m["dest"])
            else:
                if os.path.lexists(m["dest"]):
                    if os.path.islink(m["dest"]) or os.path.isfile(m["dest"]):
                        os.remove(m["dest"])
                    else:
                        shutil.rmtree(m["dest"])
                shutil.copy2(bak_path, m["dest"])
            self.refresh_file_lists()
            self.status_bar.config(text="Restored from backup")
        except Exception as e:
            messagebox.showerror("Error", str(e))

    def open_path(self, path):
        """Open file or folder in system explorer/editor asynchronously"""
        if not os.path.lexists(path):
            messagebox.showerror("Error", f"Path does not exist: {path}")
            return
            
        try:
            if self.system == "Windows":
                os.startfile(path)
            elif self.system == "Darwin":
                import subprocess
                subprocess.Popen(["open", path])
            else:
                import subprocess
                subprocess.Popen(["xdg-open", path])
        except Exception as e:
            messagebox.showerror("Error", f"Failed to open: {str(e)}")


def main():
    root = tk.Tk()
    app = DotfilesDeployGUI(root)
    root.mainloop()


if __name__ == "__main__":
    main()
