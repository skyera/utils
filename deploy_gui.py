#!/usr/bin/env python3
"""
deploy_gui.py - Cross-platform dotfiles deployment GUI
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
        self.root.geometry("1100x750")
        
        self.repo_dir = os.path.dirname(os.path.abspath(__file__))
        self.system = platform.system()
        
        # UI State
        self.backup_var = tk.BooleanVar(value=True)
        self.nvim_choice = tk.StringVar(value="lua")
        
        # Store metadata for tree items
        self.source_metadata = {}
        self.dest_metadata = {}
        
        # File configurations
        self.file_configs = self._get_file_configs()
        
        self.setup_ui()
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
                    {"src": ".config/lf/lfrc_windows", "dest": {"Windows": "%LOCALAPPDATA%/lf/lfrc"}},
                    {"src": ".config/lf/icons", "dest": {"Unix": "~/.config/lf/icons", "Windows": "%LOCALAPPDATA%/lf/icons"}},
                    {"src": ".config/lf/colors", "dest": {"Unix": "~/.config/lf/colors", "Windows": "%LOCALAPPDATA%/lf/colors"}},
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
            # Expand %VAR% style
            path = os.path.expandvars(path)
        else:
            # Expand $VAR style (os.path.expandvars handles this on Unix too)
            path = os.path.expandvars(path)
            
        return os.path.abspath(path)

    def setup_ui(self):
        # Configure overall style
        style = ttk.Style()
        # Use a more modern theme if available
        if "clam" in style.theme_names():
            style.theme_use("clam")
            
        # Define colors
        bg_color = "#f0f0f0"
        header_bg = "#2c3e50"
        header_fg = "#ecf0f1"
        
        self.root.configure(bg=bg_color)
        
        # Header section
        header_frame = tk.Frame(self.root, bg=header_bg, height=60)
        header_frame.pack(fill=tk.X)
        header_frame.pack_propagate(False)
        
        tk.Label(header_frame, text="🛡️ Dotfiles Deployer", font=("Arial", 16, "bold"), 
                 bg=header_bg, fg=header_fg).pack(side=tk.LEFT, padx=20)
        
        system_info = f"💻 {self.system} | 🏠 {os.path.expanduser('~')}"
        tk.Label(header_frame, text=system_info, font=("Arial", 10), 
                 bg=header_bg, fg=header_fg).pack(side=tk.RIGHT, padx=20)
        
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
        
        # Scrollbars
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
        
        # Text widget for diff with both scrollbars
        self.diff_text = tk.Text(diff_frame, wrap=tk.NONE, height=10,
                                font=("Consolas" if self.system == "Windows" else "Monospace", 10),
                                bg="#fdfdfd")
        
        d_scroll_y = ttk.Scrollbar(diff_frame, orient=tk.VERTICAL, command=self.diff_text.yview)
        d_scroll_x = ttk.Scrollbar(diff_frame, orient=tk.HORIZONTAL, command=self.diff_text.xview)
        self.diff_text.configure(yscrollcommand=d_scroll_y.set, xscrollcommand=d_scroll_x.set)
        
        d_scroll_y.pack(side=tk.RIGHT, fill=tk.Y)
        d_scroll_x.pack(side=tk.BOTTOM, fill=tk.X)
        self.diff_text.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        
        # Status bar
        self.status_bar = tk.Label(self.root, text="Ready", relief=tk.SUNKEN, anchor=tk.W, 
                                   padx=10, pady=5, bg="#ddd", font=("Arial", 9))
        self.status_bar.pack(fill=tk.X)
        
        # Bind events
        self.source_tree.bind("<Double-1>", self.on_source_double_click)
        self.source_tree.bind("<Button-3>", self.on_source_right_click)
        self.source_tree.bind("<<TreeviewSelect>>", self.on_tree_select)
        
        self.dest_tree.bind("<Button-3>", self.on_dest_right_click)
        self.dest_tree.bind("<<TreeviewSelect>>", self.on_tree_select)
        
        # Tags for status colors and zebra striping
        for tree in [self.source_tree, self.dest_tree]:
            tree.tag_configure("green", foreground="#27ae60", font=("Arial", 9, "bold"))
            tree.tag_configure("orange", foreground="#d35400", font=("Arial", 9, "bold"))
            tree.tag_configure("red", foreground="#c0392b", font=("Arial", 9, "bold"))
            tree.tag_configure("gray", foreground="#7f8c8d")
            tree.tag_configure("odd", background="#ffffff")
            tree.tag_configure("even", background="#f9f9f9")

        # Diff tags
        self.diff_text.tag_configure("diff_add", foreground="#27ae60", background="#e8f8f5")
        self.diff_text.tag_configure("diff_sub", foreground="#c0392b", background="#f9ebeb")
        self.diff_text.tag_configure("diff_header", foreground="#2980b9", font=("Arial", 10, "bold"))
        self.diff_text.config(state=tk.DISABLED)

    def get_sync_status(self, src, dest, is_dir=False):
        """Compare src and dest to get status with icons"""
        if not os.path.exists(src):
            return "❔ Missing Src", "gray"
        
        if not os.path.exists(dest):
            return "❌ Missing", "red"
        
        try:
            if is_dir:
                return "✅ Exists", "green"
            else:
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
        """Generate and display unified diff in the text widget"""
        self.diff_text.config(state=tk.NORMAL)
        self.diff_text.delete(1.0, tk.END)
        
        if is_dir:
            self.diff_text.insert(tk.END, f"Directory comparison not supported in diff view.\nSource: {src}\nDestination: {dest}")
        elif not os.path.exists(src):
            self.diff_text.insert(tk.END, f"Source file missing: {src}")
        elif not os.path.exists(dest):
            self.diff_text.insert(tk.END, f"Destination file missing (New file):\n\n")
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
                    self.diff_text.insert(tk.END, "✨ Files are identical.")
                    
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
                # Check condition (e.g., nvim choice)
                if "condition" in item:
                    if item["condition"] != self.nvim_choice.get():
                        continue
                
                src_path = os.path.join(self.repo_dir, item["src"])
                dest_path = self.resolve_path(item["dest"])
                
                if not dest_path:
                    continue
                
                is_dir = item.get("is_dir", False)
                status, color = self.get_sync_status(src_path, dest_path, is_dir)
                
                # Zebra stripe tag
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


    def deploy_file(self, src, dest, is_dir=False):
        """Core deployment logic for single file or directory"""
        if not os.path.exists(src):
            return False, f"Source not found: {src}"
        
        try:
            # Create parent directory
            dest_dir = os.path.dirname(dest)
            if not os.path.exists(dest_dir):
                os.makedirs(dest_dir)
            
            # Backup
            if self.backup_var.get() and os.path.exists(dest):
                bak_path = dest + ".bak"
                if os.path.isdir(dest):
                    if os.path.exists(bak_path):
                        shutil.rmtree(bak_path)
                    shutil.copytree(dest, bak_path)
                else:
                    shutil.copy2(dest, bak_path)
            
            # Deploy
            if is_dir:
                if os.path.exists(dest):
                    if os.path.islink(dest):
                        os.unlink(dest)
                    elif os.path.isdir(dest):
                        shutil.rmtree(dest)
                    else:
                        os.remove(dest)
                shutil.copytree(src, dest)
            else:
                shutil.copy2(src, dest)
                # Permissions
                if self.system != "Windows":
                    if "/bin/" in src or src.endswith(".sh"):
                        os.chmod(dest, 0o755)
            
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
            # Category
            menu.add_command(label="Deploy Category", command=lambda: self.deploy_category(item_id))
            
        menu.post(event.x_root, event.y_root)

    def on_dest_right_click(self, event):
        selection = self.dest_tree.selection()
        if not selection: return
        
        item_id = selection[0]
        if item_id not in self.dest_metadata: return
        
        m = self.dest_metadata[item_id]
        menu = tk.Menu(self.root, tearoff=0)
        menu.add_command(label="Open File", command=lambda: self.open_path(m["dest"]))
        menu.add_command(label="Open Location", command=lambda: self.open_path(os.path.dirname(m["dest"])))
        
        bak_path = m["dest"] + ".bak"
        if os.path.exists(bak_path):
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
                if os.path.exists(m["dest"]): shutil.rmtree(m["dest"])
                shutil.copytree(bak_path, m["dest"])
            else:
                shutil.copy2(bak_path, m["dest"])
            self.refresh_file_lists()
            self.status_bar.config(text="Restored from backup")
        except Exception as e:
            messagebox.showerror("Error", str(e))

    def open_path(self, path):
        """Open file or folder in system explorer/editor"""
        if not os.path.exists(path):
            messagebox.showerror("Error", f"Path does not exist: {path}")
            return
            
        try:
            if self.system == "Windows":
                os.startfile(path)
            elif self.system == "Darwin":
                import subprocess
                subprocess.run(["open", path])
            else:
                import subprocess
                subprocess.run(["xdg-open", path])
        except Exception as e:
            messagebox.showerror("Error", f"Failed to open: {str(e)}")


def main():
    root = tk.Tk()
    # Simple styling
    style = ttk.Style()
    style.configure("Treeview", font=("Segoe UI" if platform.system() == "Windows" else "Sans", 10))
    style.configure("Treeview.Heading", font=("Segoe UI" if platform.system() == "Windows" else "Sans", 10, "bold"))
    
    app = DotfilesDeployGUI(root)
    root.mainloop()


if __name__ == "__main__":
    main()
