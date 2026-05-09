#!/usr/bin/env python3
"""
deploy_split_gui.py - Split-pane file manager style deployment GUI
"""

import tkinter as tk
from tkinter import ttk, messagebox
import os
import shutil
import filecmp
from datetime import datetime


class SplitPaneDeployGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("Dotfiles Deployer - Split View")
        self.root.geometry("1000x700")
        
        self.repo_dir = os.path.dirname(os.path.abspath(__file__))
        self.home_dir = os.path.expanduser("~")
        
        # File mapping: source -> destination
        self.file_mapping = self._build_file_mapping()
        
        # Store metadata for tree items
        self.source_metadata = {}
        self.dest_metadata = {}
        
        self.setup_ui()
        self.refresh_file_lists()
    
    def _build_file_mapping(self):
        """Build mapping of source files to their destination paths"""
        mapping = {}
        
        # Shell configs
        mapping["mybashrc"] = os.path.join(self.home_dir, ".mybashrc")
        mapping["myvimrc"] = os.path.join(self.home_dir, ".vimrc")
        
        # Dotfiles
        mapping[".gitconfig"] = os.path.join(self.home_dir, ".gitconfig")
        mapping[".tmux.conf"] = os.path.join(self.home_dir, ".tmux.conf")
        mapping[".tigrc"] = os.path.join(self.home_dir, ".tigrc")
        mapping[".ripgreprc"] = os.path.join(self.home_dir, ".ripgreprc")
        mapping[".gdbinit"] = os.path.join(self.home_dir, ".gdbinit")
        
        # Config directories
        mapping[".config/lf/lfrc"] = os.path.join(self.home_dir, ".config", "lf", "lfrc")
        mapping[".config/lf/icons"] = os.path.join(self.home_dir, ".config", "lf", "icons")
        mapping[".config/lf/colors"] = os.path.join(self.home_dir, ".config", "lf", "colors")
        mapping[".config/fd/ignore"] = os.path.join(self.home_dir, ".config", "fd", "ignore")
        mapping[".config/git/ignore"] = os.path.join(self.home_dir, ".config", "git", "ignore")
        mapping[".vifm/vifmrc"] = os.path.join(self.home_dir, ".vifm", "vifmrc")
        
        # Yazi
        mapping[".config/yazi/theme.toml"] = os.path.join(self.home_dir, ".config", "yazi", "theme.toml")
        mapping[".config/yazi/keymap.toml"] = os.path.join(self.home_dir, ".config", "yazi", "keymap.toml")
        
        # Ranger
        mapping[".config/ranger/rc.conf"] = os.path.join(self.home_dir, ".config", "ranger", "rc.conf")
        mapping[".config/ranger/commands.py"] = os.path.join(self.home_dir, ".config", "ranger", "commands.py")
        mapping[".config/ranger/scope.sh"] = os.path.join(self.home_dir, ".config", "ranger", "scope.sh")
        
        return mapping
    
    def setup_ui(self):
        # Top toolbar
        toolbar = ttk.Frame(self.root, padding="5")
        toolbar.pack(fill=tk.X)
        
        ttk.Button(toolbar, text="Refresh", command=self.refresh_file_lists).pack(side=tk.LEFT, padx=5)
        ttk.Button(toolbar, text="Deploy Selected", command=self.deploy_selected).pack(side=tk.LEFT, padx=5)
        ttk.Button(toolbar, text="Deploy All", command=self.deploy_all).pack(side=tk.LEFT, padx=5)
        ttk.Separator(toolbar, orient=tk.VERTICAL).pack(side=tk.LEFT, padx=10, fill=tk.Y)
        
        self.backup_var = tk.BooleanVar(value=True)
        ttk.Checkbutton(toolbar, text="Backup files", variable=self.backup_var).pack(side=tk.LEFT, padx=5)
        
        # Legend
        legend_frame = ttk.Frame(toolbar)
        legend_frame.pack(side=tk.RIGHT, padx=5)
        ttk.Label(legend_frame, text="Status: ", font=("Arial", 9, "bold")).pack(side=tk.LEFT)
        ttk.Label(legend_frame, text="✓ Synced", foreground="green").pack(side=tk.LEFT, padx=5)
        ttk.Label(legend_frame, text="⚠ Outdated", foreground="orange").pack(side=tk.LEFT, padx=5)
        ttk.Label(legend_frame, text="✗ Missing", foreground="red").pack(side=tk.LEFT, padx=5)
        
        # Main paned window
        self.paned = ttk.PanedWindow(self.root, orient=tk.HORIZONTAL)
        self.paned.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)
        
        # Left pane - Source files
        left_frame = ttk.LabelFrame(self.paned, text="Source (Repository)", padding="5")
        self.paned.add(left_frame, weight=1)
        
        # Source treeview
        self.source_tree = ttk.Treeview(left_frame, columns=("status",), show="tree headings")
        self.source_tree.heading("#0", text="File")
        self.source_tree.heading("status", text="Status")
        self.source_tree.column("#0", width=300)
        self.source_tree.column("status", width=80)
        self.source_tree.pack(fill=tk.BOTH, expand=True)
        
        # Source scrollbar
        source_scroll = ttk.Scrollbar(left_frame, orient=tk.VERTICAL, command=self.source_tree.yview)
        source_scroll.pack(side=tk.RIGHT, fill=tk.Y)
        self.source_tree.configure(yscrollcommand=source_scroll.set)
        
        # Right pane - Destination files
        right_frame = ttk.LabelFrame(self.paned, text="Destination (Home)", padding="5")
        self.paned.add(right_frame, weight=1)
        
        # Destination treeview
        self.dest_tree = ttk.Treeview(right_frame, columns=("status",), show="tree headings")
        self.dest_tree.heading("#0", text="File")
        self.dest_tree.heading("status", text="Status")
        self.dest_tree.column("#0", width=300)
        self.dest_tree.column("status", width=80)
        self.dest_tree.pack(fill=tk.BOTH, expand=True)
        
        # Destination scrollbar
        dest_scroll = ttk.Scrollbar(right_frame, orient=tk.VERTICAL, command=self.dest_tree.yview)
        dest_scroll.pack(side=tk.RIGHT, fill=tk.Y)
        self.dest_tree.configure(yscrollcommand=dest_scroll.set)
        
        # Status bar
        self.status_bar = ttk.Label(self.root, text="Ready", relief=tk.SUNKEN, padding="5")
        self.status_bar.pack(fill=tk.X)
        
        # Bind events
        self.source_tree.bind("<Double-1>", self.on_source_double_click)
        self.dest_tree.bind("<Double-1>", self.on_dest_double_click)
        self.source_tree.bind("<Button-3>", self.on_source_right_click)
        self.dest_tree.bind("<Button-3>", self.on_dest_right_click)
    
    def get_file_status(self, src, dest):
        """Get sync status of a file"""
        if not os.path.exists(src):
            return "✗ Source missing", "red"
        
        if not os.path.exists(dest):
            return "✗ Missing", "red"
        
        if filecmp.cmp(src, dest, shallow=False):
            return "✓ Synced", "green"
        else:
            return "⚠ Outdated", "orange"
    
    def refresh_file_lists(self):
        """Refresh both file lists"""
        # Clear existing items and metadata
        for item in self.source_tree.get_children():
            self.source_tree.delete(item)
        for item in self.dest_tree.get_children():
            self.dest_tree.delete(item)
        self.source_metadata.clear()
        self.dest_metadata.clear()
        
        # Group files by category
        categories = {
            "Shell Configs": ["mybashrc"],
            "Editor Configs": ["myvimrc"],
            "Dotfiles": [".gitconfig", ".tmux.conf", ".tigrc", ".ripgreprc", ".gdbinit"],
            "Config Files": [
                ".config/lf/lfrc", ".config/lf/icons", ".config/lf/colors",
                ".config/fd/ignore", ".config/git/ignore",
                ".config/yazi/theme.toml", ".config/yazi/keymap.toml",
                ".config/ranger/rc.conf", ".config/ranger/commands.py", ".config/ranger/scope.sh",
                ".vifm/vifmrc"
            ]
        }
        
        # Populate source tree
        for category, files in categories.items():
            cat_id = self.source_tree.insert("", tk.END, text=category, open=True)
            for file in files:
                src = os.path.join(self.repo_dir, file)
                dest = self.file_mapping.get(file, "")
                status, color = self.get_file_status(src, dest)
                
                # Store metadata in dictionary
                item_id = self.source_tree.insert(
                    cat_id,
                    tk.END,
                    text=os.path.basename(file),
                    values=(status,),
                    tags=(color,)
                )
                self.source_metadata[item_id] = {
                    "full_path": src,
                    "dest_path": dest,
                    "relative_path": file
                }
        
        # Populate destination tree
        for category, files in categories.items():
            cat_id = self.dest_tree.insert("", tk.END, text=category, open=True)
            for file in files:
                src = os.path.join(self.repo_dir, file)
                dest = self.file_mapping.get(file, "")
                status, color = self.get_file_status(src, dest)
                
                item_id = self.dest_tree.insert(
                    cat_id,
                    tk.END,
                    text=os.path.basename(file),
                    values=(status,),
                    tags=(color,)
                )
                self.dest_metadata[item_id] = {
                    "full_path": dest,
                    "src_path": src,
                    "relative_path": file
                }
        
        # Configure tags for colors
        self.source_tree.tag_configure("green", foreground="green")
        self.source_tree.tag_configure("orange", foreground="orange")
        self.source_tree.tag_configure("red", foreground="red")
        self.dest_tree.tag_configure("green", foreground="green")
        self.dest_tree.tag_configure("orange", foreground="orange")
        self.dest_tree.tag_configure("red", foreground="red")
        
        self.status_bar.config(text=f"Loaded {len(self.file_mapping)} files")
    
    def on_source_double_click(self, event):
        """Deploy file when double-clicked in source"""
        selection = self.source_tree.selection()
        if selection:
            item = selection[0]
            # Check if it's a category (parent)
            if self.source_tree.parent(item):
                metadata = self.source_metadata.get(item, {})
                src = metadata.get("full_path")
                dest = metadata.get("dest_path")
                if src and dest:
                    self.deploy_file(src, dest)
    
    def on_dest_double_click(self, event):
        """View file info when double-clicked in destination"""
        selection = self.dest_tree.selection()
        if selection:
            item = selection[0]
            if self.dest_tree.parent(item):
                metadata = self.dest_metadata.get(item, {})
                dest = metadata.get("full_path")
                src = metadata.get("src_path")
                if dest and os.path.exists(dest):
                    self.show_file_info(src, dest)
    
    def on_source_right_click(self, event):
        """Show context menu for source tree"""
        selection = self.source_tree.selection()
        if selection:
            item = selection[0]
            if self.source_tree.parent(item):
                metadata = self.source_metadata.get(item, {})
                menu = tk.Menu(self.root, tearoff=0)
                menu.add_command(label="Deploy this file", command=lambda: self.deploy_source_item(item))
                menu.add_command(label="View source", command=lambda: self.view_file(metadata.get("full_path")))
                menu.add_separator()
                menu.add_command(label="Deploy all in category", command=lambda: self.deploy_category(item, "source"))
                menu.post(event.x_root, event.y_root)
    
    def on_dest_right_click(self, event):
        """Show context menu for destination tree"""
        selection = self.dest_tree.selection()
        if selection:
            item = selection[0]
            if self.dest_tree.parent(item):
                metadata = self.dest_metadata.get(item, {})
                menu = tk.Menu(self.root, tearoff=0)
                menu.add_command(label="View file info", command=lambda: self.show_file_info(
                    metadata.get("src_path"),
                    metadata.get("full_path")
                ))
                menu.add_command(label="View destination", command=lambda: self.view_file(metadata.get("full_path")))
                menu.add_separator()
                if os.path.exists(metadata.get("full_path", "") + ".bak"):
                    menu.add_command(label="Restore from backup", command=lambda: self.restore_backup(item))
                menu.post(event.x_root, event.y_root)
    
    def deploy_source_item(self, item):
        """Deploy a single item from source tree"""
        metadata = self.source_metadata.get(item, {})
        src = metadata.get("full_path")
        dest = metadata.get("dest_path")
        if src and dest:
            self.deploy_file(src, dest)
    
    def deploy_category(self, item, tree_type):
        """Deploy all files in a category"""
        if tree_type == "source":
            tree = self.source_tree
            metadata_dict = self.source_metadata
            get_path = lambda i: (metadata_dict.get(i, {}).get("full_path"), metadata_dict.get(i, {}).get("dest_path"))
        else:
            tree = self.dest_tree
            metadata_dict = self.dest_metadata
            get_path = lambda i: (metadata_dict.get(i, {}).get("src_path"), metadata_dict.get(i, {}).get("full_path"))
        
        # Get all children of the category
        parent = tree.parent(item)
        if parent:
            # Item is a file, get its category
            category_id = parent
        else:
            # Item is a category
            category_id = item
        
        children = tree.get_children(category_id)
        for child in children:
            src, dest = get_path(child)
            if src and dest:
                self.deploy_file(src, dest)
        
        self.refresh_file_lists()
    
    def deploy_file(self, src, dest):
        """Deploy a single file"""
        if not os.path.exists(src):
            messagebox.showerror("Error", f"Source file not found: {src}")
            return False
        
        try:
            # Create destination directory if needed
            dest_dir = os.path.dirname(dest)
            if dest_dir and not os.path.exists(dest_dir):
                os.makedirs(dest_dir)
            
            # Backup if requested and file exists
            if os.path.exists(dest) and self.backup_var.get():
                backup_path = dest + ".bak"
                shutil.copy2(dest, backup_path)
                self.status_bar.config(text=f"Backed up {dest} to {backup_path}")
            
            # Copy file
            shutil.copy2(src, dest)
            self.status_bar.config(text=f"Deployed {dest}")
            
            # Make executable if it's a script
            if dest.endswith(".sh") or "/bin/" in dest:
                os.chmod(dest, 0o755)
            
            self.refresh_file_lists()
            return True
            
        except Exception as e:
            messagebox.showerror("Error", f"Failed to deploy {dest}: {str(e)}")
            return False
    
    def deploy_selected(self):
        """Deploy all selected files from source tree"""
        selection = self.source_tree.selection()
        if not selection:
            messagebox.showinfo("Info", "No files selected")
            return
        
        count = 0
        for item in selection:
            if self.source_tree.parent(item):  # Only files, not categories
                metadata = self.source_metadata.get(item, {})
                src = metadata.get("full_path")
                dest = metadata.get("dest_path")
                if src and dest:
                    if self.deploy_file(src, dest):
                        count += 1
        
        messagebox.showinfo("Success", f"Deployed {count} file(s)")
    
    def deploy_all(self):
        """Deploy all files"""
        if not messagebox.askyesno("Confirm", "Deploy all files?"):
            return
        
        count = 0
        for src, dest in self.file_mapping.items():
            src_path = os.path.join(self.repo_dir, src)
            if src_path and dest:
                if self.deploy_file(src_path, dest):
                    count += 1
        
        messagebox.showinfo("Success", f"Deployed {count} file(s)")
    
    def show_file_info(self, src, dest):
        """Show information about a file"""
        info = f"Source: {src}\n"
        info += f"Destination: {dest}\n\n"
        
        if os.path.exists(src):
            info += f"Source size: {os.path.getsize(src)} bytes\n"
            info += f"Source modified: {datetime.fromtimestamp(os.path.getmtime(src))}\n"
        else:
            info += "Source: Not found\n"
        
        if os.path.exists(dest):
            info += f"Dest size: {os.path.getsize(dest)} bytes\n"
            info += f"Dest modified: {datetime.fromtimestamp(os.path.getmtime(dest))}\n"
            
            if os.path.exists(src) and filecmp.cmp(src, dest, shallow=False):
                info += "\nFiles are identical"
            else:
                info += "\nFiles differ"
        else:
            info += "Destination: Not found\n"
        
        messagebox.showinfo("File Info", info)
    
    def view_file(self, filepath):
        """View file contents (simple text viewer)"""
        if not os.path.exists(filepath):
            messagebox.showerror("Error", f"File not found: {filepath}")
            return
        
        try:
            with open(filepath, 'r', errors='ignore') as f:
                content = f.read()
            
            # Create simple viewer window
            viewer = tk.Toplevel(self.root)
            viewer.title(f"View: {os.path.basename(filepath)}")
            viewer.geometry("800x600")
            
            text = tk.Text(viewer, wrap=tk.WORD)
            text.pack(fill=tk.BOTH, expand=True)
            text.insert(tk.END, content)
            text.config(state=tk.DISABLED)
            
        except Exception as e:
            messagebox.showerror("Error", f"Failed to read file: {str(e)}")
    
    def restore_backup(self, item):
        """Restore file from backup"""
        metadata = self.dest_metadata.get(item, {})
        dest = metadata.get("full_path")
        backup = dest + ".bak"
        
        if not os.path.exists(backup):
            messagebox.showerror("Error", "No backup found")
            return
        
        if messagebox.askyesno("Confirm", f"Restore {dest} from backup?"):
            try:
                shutil.copy2(backup, dest)
                self.status_bar.config(text=f"Restored {dest} from backup")
                self.refresh_file_lists()
            except Exception as e:
                messagebox.showerror("Error", f"Failed to restore: {str(e)}")


def main():
    root = tk.Tk()
    app = SplitPaneDeployGUI(root)
    root.mainloop()


if __name__ == "__main__":
    main()