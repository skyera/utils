local wezterm = require("wezterm")
local config = wezterm.config_builder()

config.launch_menu = {
    { label = "PowerShell", args = { "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" } },
    { label = "Command Prompt", args = { "cmd.exe" } },
    { label = "Git Bash", args = { "C:\\Program Files\\Git\\bin\\bash.exe", "-l" } },
    { label = "WSL", args = { "wsl.exe" } },
}
config.default_prog = { "cmd"}
config.color_scheme = "Tokyo Night"
config.font_size = 11.0

return config
