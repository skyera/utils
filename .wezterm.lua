local wezterm = require("wezterm")
local config = wezterm.config_builder()

config.launch_menu = {
    { label = "PowerShell", args = { "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" } },
    { label = "Command Prompt", args = { "cmd.exe" } },
    { label = "Git Bash", args = { "C:\\Program Files\\Git\\bin\\bash.exe", "-l" } },
    { label = "WSL", args = { "wsl.exe" } },
    { label = "centre", args = {"ssh", "zliu@192.168.1.44"} },
    { label = "pi4" , args = {"ssh", "pi@192.168.1.10"} },
    { label="jet", args={"ssh", "zliu@192.168.1.5"}},
    { label="pi0", args={"ssh", "pi@192.168.1.49"}" }
}
config.default_prog = { "cmd"}
config.color_scheme = "Tokyo Night"
config.window_background_opacity = 0.9
config.text_background_opacity = 0.8
config.window_close_confirmation = "AlwaysPrompt"
config.use_fancy_tab_bar = false

config.font = wezterm.font_with_fallback({
    'Hack Nerd Font',
    'JetBrains Mono',
})

config.font_size = 10.0
config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"
config.enable_tab_bar = true
config.enable_scroll_bar = true
config.tab_max_width = 32
config.colors = {
    tab_bar = {
        active_tab = {
            fg_color = '#073642',
            bg_color = '#2aa198',
        }
    }
}

config.leader = { key = "Space", mods = "CTRL", timeout_milliseconds = 2000 }

config.keys = {
    {key='"', mods="CTRL|SHIFT", action=wezterm.action.SplitVertical{domain="CurrentPaneDomain"}},
    {key='%', mods="CTRL|SHIFT", action=wezterm.action.SplitHorizontal{domain="CurrentPaneDomain"}},

    {
        key = ',',
        mods = 'LEADER',
        action = wezterm.action.PromptInputLine {
            description = 'Enter new name for tab',
            action = wezterm.action_callback(
                function(window, pane, line)
                    if line then
                        window:active_tab():set_title(line)
                    end
                end
                ),
        },
    },
}

wezterm.on("update-status", function(window, pane)
    local overrides = window:get_config_overrides() or {}
    local dimensions = pane:get_dimensions()

    overrides.enable_scroll_bar = dimensions.scrollback_rows > dimensions.viewport_rows and not pane:is_alt_screen_active()

    window:set_config_overrides(overrides)
  
  local bg = window:effective_config().resolved_palette.background
  window:set_right_status(wezterm.format {
    { Background = { Color = bg } },
    { Foreground = { Color = '#ffffff' } },
    { Text = ' ' .. wezterm.hostname() .. ' | ' .. wezterm.strftime('%H:%M') .. ' ' },
  })
end)

return config
