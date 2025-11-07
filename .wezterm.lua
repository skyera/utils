local wezterm = require("wezterm")
local config = wezterm.config_builder()

config.launch_menu = {
    { label = "PowerShell", args = { "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" } },
    { label = "Command Prompt", args = { "cmd.exe" } },
    { label = "Git Bash", args = { "C:\\Program Files\\Git\\bin\\bash.exe", "-l" } },
    { label = "WSL", args = { "wsl.exe" } },
    { label = "centre", args = {"ssh", "zliu@192.168.1.44"} },
    { label = "pi4" , args = {"ssh", "pi@192.168.1.10"} }
}
config.default_prog = { "cmd"}
config.color_scheme = "Tokyo Night"
config.window_background_opacity = 0.9
config.window_close_confirmation = "AlwaysPrompt"
config.use_fancy_tab_bar = false

config.font = wezterm.font_with_fallback({
    'Hack Nerd Font',
    'JetBrains Mono',
})

config.font_size = 10.0
config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"
config.enable_tab_bar = true

config.keys = {
    {key="%", mods="CTRL|SHIFT", action=wezterm.action.SplitVertical{domain="CurrentPaneDomain"}},
    {key='"', mods="CTRL|SHIFT", action=wezterm.action.SplitHorizontal{domain="CurrentPaneDomain"}},
}

return config







