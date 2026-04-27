# utils
```
 _   _ _   _ _
| | | | |_(_) |___
| | | | __| | / __|
| |_| | |_| | \__ \
 \___/ \__|_|_|___/
```

Personal utility scripts, binary tools, and text editor configurations.

## Features

- **Vim & Neovim Configurations**: Includes a robust classic `myvimrc` and a modern Neovim Lua configuration (`.config/nvim`).
- **Binary Tools**: A collection of helpful shell scripts, batch files, and binaries located in the `bin/` directory (e.g., FZF wrappers, LF previewers).
- **Deployment Script**: A `deploy.bat` script for Windows that automates the installation of configurations and binaries.

## Deployment (Windows)

Use the included `deploy.bat` script to easily deploy configurations and scripts to your local environment. It copies binaries to `C:\app\bin` and sets up the necessary environment variables.

### Usage

```cmd
deploy.bat [OPTIONS]
```

**Options:**
- `/l`, `--lua` : Deploy the modern Neovim Lua configuration (Default).
- `/v`, `--vim` : Deploy the classic `myvimrc` as `init.vim` for Neovim.
- `/h`, `--help`: Show the help message.

**Note:** Ensure that `C:\app\bin` is added to your system's `PATH`.
