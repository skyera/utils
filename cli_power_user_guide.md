# CLI Power User Guide: Tools & Ninja Tips

Welcome to your custom-tailored **CLI Power User Guide**. Based on your existing setup (which already includes `fzf`, `ripgrep`, `fd`, `eza`, `zoxide`, `yazi`, and `delta`), this guide focuses on **advanced upgrades**, **ninja shell techniques**, and **ready-to-run configurations** that will instantly elevate your daily workflow.

---

## 🚀 1. The Modern Rust CLI Toolkit

While you are already familiar with the foundational modern CLI stack, these Rust-based additions are game-changers for productivity, benchmarking, and hot-reloading.

### `sd` — Intuitive Regex Search & Replace
Standard `sed` has cryptic regex syntax that differs between GNU (Linux) and BSD (macOS) systems. `sd` is a modern replacement that uses standard regex syntax (Rust-regex) and is **10x to 100x faster**.

| Feature | `sed` (Standard) | `sd` (Modern Rust) |
| :--- | :--- | :--- |
| **Basic Replace** | `sed -i 's/foo/bar/g' file.txt` | `sd 'foo' 'bar' file.txt` |
| **Capture Groups** | `sed -i -E 's/([0-9]+)px/\1em/g'` | `sd '(\d+)px' '$1em' file.txt` |
| **Multi-file Replace** | `find . -name "*.txt" -exec sed -i ...` | `fd -e txt | xargs sd 'foo' 'bar'` |

> [!TIP]
> `sd` defaults to modifying files **in-place**. If you want to do a dry-run and see the changes without writing them, simply omit the file argument and pipe content into it:
> `cat file.txt | sd 'foo' 'bar'`

---

### `bottom` (`btm`) — Graphical System Monitor
While `htop` is great, `bottom` is a highly graphical, fully customizable system monitor written in Rust that feels incredibly premium and sci-fi.

* **Key features**: Real-time graphs for CPU, RAM, temperature sensors, disk I/O, network bandwidth, and process tree structures.
* **Ninja Keyboard Controls**:
  * `Tab` — Switch between active panels.
  * `/` — Filter processes.
  * `F6` — Sort processes by CPU, Mem, PID, etc.
  * `e` — Expand the currently active panel to full screen (press `e` again to shrink).
  * `Tab` -> `dd` — Instantly kill the selected process.

---

### `dust` — Visual Disk Usage Analyzer
If you've ever run out of disk space and wrestled with `du -sh * | sort -h`, `dust` is your savior. It analyzes directories and displays them as a gorgeous visual, color-coded tree.

```bash
dust -d 2  # Show disk usage tree up to 2 levels deep
```
* **Why it's better than `ncdu`**: It doesn't require interactive scanning; it spits out a beautiful tree directly into stdout, which can be piped, reviewed, or logged.

---

### `entr` — Event-Driven Hot Reloader
`entr` is an incredibly simple yet powerful tool that runs an arbitrary command whenever a list of files changes. It makes local test loops completely automatic.

```bash
# Automatically run tests when any Python file changes
find . -name "*.py" | entr pytest

# Automatically compile C++ code and run the binary when source files change
# The -r flag sends a SIGTERM to the running process and restarts it
fd -e cpp -e h | entr -r make test
```

---

### `tealdeer` (`tldr`) — Practical CLI Cheat Sheets
Standard `man` pages are dry, academic, and require scrolling through thousands of lines of options just to find a simple syntax combination. `tealdeer` is a blazing-fast Rust implementation of `tldr` that gives you **exactly 5-6 practical examples** of how a command is actually used.

```bash
tldr tar      # Instantly see how to extract, compress, or list files
tldr find     # See common find recipes (size, time, extensions)
```

---

## 🛠️ 2. Advanced FZF Integrations (For your `mybashrc`)

Since you are already a power user of `fzf` with a curated pastel color palette, here are two pending items from your `PROPOSED_IMPROVEMENTS.md` written specifically to integrate into your configuration. 

You can copy and paste these directly into your [`mybashrc`](file:///home/pi/test/utils/mybashrc):

### 1. Smarter `fkill` (Interactive Process Manager)
This wrapper retrieves all active processes running under your username, formats them with CPU and memory details, and loads them into `fzf`. It supports **multi-select** so you can kill multiple processes simultaneously.

```bash
# Interactive multi-select process killer using FZF
fkill() {
    local pids
    # Multi-select process selection
    pids=$(ps -u "$USER" -o pid,ppid,%cpu,%mem,start,time,command | \
        fzf --multi \
            --header-lines=1 \
            --header="[Process Killer] Tab: multi-select, Enter: SIGTERM (15)" \
            --preview 'echo {}' \
            --preview-window=down:3:wrap | \
        awk '{print $1}')

    if [[ -n "$pids" ]]; then
        # Prompt confirmation for safety
        echo "The following processes will be terminated:"
        echo "$pids" | xargs ps -p
        read -p "Are you sure you want to terminate these processes? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "$pids" | xargs kill -15
            echo -e "\033[32m✔ Processes terminated.\033[0m"
        else
            echo "Cancelled."
        fi
    fi
}
```

---

### 2. Interactive `zi` (Zoxide Jump with File Tree Preview)
You already have `zoxide` directory jumping. This `zi` integration maps your `zoxide` recent directory history to `fzf` and uses your modern `eza --tree` configuration as a dynamic, real-time preview panel on the right side!

```bash
# Interactive zoxide directory jumper with eza tree preview
zi() {
    local dir
    dir=$(zoxide query -l | fzf --no-sort --keep-right \
        --header="[Zoxide Interactive Jump]" \
        --preview 'eza -T --color=always --level=2 --icons=always {} 2>/dev/null || ls -R {} 2>/dev/null | head -50' \
        --preview-window=right:50%:wrap)
    
    if [[ -n "$dir" ]]; then
        cd "$dir" || return
    fi
}
```

---

## 🎛️ 3. Multiplexer & Terminal Masterclass

### WezTerm: Quick Select Mode (No Mouse Required!)
Since you are using WezTerm (`.wezterm.lua`), you can entirely stop using the mouse to copy hashes, paths, or URLs from your terminal screen.

* **Trigger**: Press `Ctrl + Shift + Space` (WezTerm default) or `Cmd + Shift + Space` (macOS).
* **What happens**: WezTerm will instantly parse the screen for common patterns (Git hashes, paths, URLs, numbers, hex colors, IPs) and assign overlay letters (e.g. `[a]`, `[b]`, `[c]`) to each.
* **Action**: Press the overlay letter, and WezTerm will instantly copy that exact text to your clipboard.

> [!NOTE]
> You can customize these patterns or keybindings in your WezTerm configuration to quickly capture customized log formats, JIRA ticket patterns, or build numbers.

---

### Tmux: Pane Synchronization
If you have multiple servers or directories to manage simultaneously, Tmux lets you broadcast your keystrokes to all active panes in a window.

1. Split your Tmux window into multiple panes.
2. Enter command mode by typing `Ctrl + b` (or your custom prefix) followed by `:`
3. Type:
   ```tmux
   setw synchronize-panes on
   ```
4. Now, whatever you type will execute **synchronously** in all panes!
5. To disable, open command mode `:` and type:
   ```tmux
   setw synchronize-panes off
   ```

---

## 🥷 4. Unix Shell Ninja Tips

These built-in terminal shortcuts require zero external packages but dramatically speed up navigation and debugging.

### Edit Long Commands in Neovim (`Ctrl + X Ctrl + E`)
If you are typing a complex bash loop, an nested command, or a multi-line curl statement, trying to navigate using left/right arrow keys is tedious.
* **Shortcut**: Press **`Ctrl + x`** followed by **`Ctrl + e`**.
* **What happens**: The shell will instantly dump your current command line into a temporary file and open it in your default `$EDITOR` (which you set to `nvim`/`vim` in `mybashrc`!).
* **Action**: Edit your long command with Vim splits, visual blocks, or regex. When you save and close (`:wq`), **the shell immediately runs the command!**

---

### Background, Detach, and Resume (`disown`)
If you start a long-running process (e.g. a local server or a build) and realize you need to close your terminal window without killing the process:

1. Pause the running process with **`Ctrl + z`**.
2. Run **`bg`** to resume it in the background of the shell.
3. Run **`disown -h %1`** (or just `disown` for the last job).
4. The process is now detached from your terminal session. You can close your terminal window entirely, and the process will continue running seamlessly in the background!

---

### Instantly Re-run with Sudo (`sudo !!`)
If you run a long command only to receive a `Permission Denied` error:
```bash
sudo !!
```
* **Explanation**: `!!` acts as a bash expansion representing the "entire last command". This saves you from pressing up and navigating back to prepend `sudo`.

---

## 📈 Next Steps
To get these custom FZF script integrations working:
1. Open your [`mybashrc`](file:///home/pi/test/utils/mybashrc).
2. Append the custom `fkill()` and `zi()` functions in the `# =============================================================================\n# ALIASES` or `# PLUGINS` section.
3. Run `reload` or open a new terminal window to activate them!
