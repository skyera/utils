local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- Launch Menu Options
config.launch_menu = {
    { label = "PowerShell", args = { "powershell.exe", "-NoLogo" } },
    { label = "Command Prompt", args = { "cmd.exe" } },
    { label = "Git Bash", args = { "bash.exe", "-l" } },
    { label = "WSL", args = { "wsl.exe" } },
    { label = "centre", args = { "ssh", "zliu@192.168.1.44" } },
    { label = "pi4", args = { "ssh", "pi@192.168.1.10" } },
    { label = "jet", args = { "ssh", "zliu@192.168.1.5" } },
    { label = "pi0", args = { "ssh", "pi@192.168.1.49" } },
    { label = "pi3", args = { "ssh", "pi@192.168.1.48" } },
    { label = "pad", args = { "ssh", "zliu@pad" } },
    { label = "pi5", args = { "ssh", "pi@pi5" } },
}

-- Default Shell per OS
local target = wezterm.target_triple
if target:find("windows") then
    config.default_prog = { "powershell.exe", "-NoLogo" }
elseif target:find("darwin") then
    config.default_prog = { "/bin/zsh" }
else
    config.default_prog = { "bash" }
end

-- Appearance & Theme
config.color_scheme = "GruvboxDark"
config.window_close_confirmation = "NeverPrompt"
config.use_fancy_tab_bar = false
config.window_padding = { left = 4, right = 4, top = 4, bottom = 4 }
config.audible_bell = "Disabled"
config.enable_kitty_keyboard = true

-- Font Configuration
config.font = wezterm.font_with_fallback({
    'Hack Nerd Font',
    'JetBrains Mono',
    'Segoe UI Emoji',
    'Microsoft YaHei',
})
config.font_size = 10.0

-- Tab Bar & Scroll Bar
config.enable_tab_bar = true
config.enable_scroll_bar = true
config.tab_max_width = 32
config.colors = {
    tab_bar = {
        background = '#1d2021',
        active_tab = {
            fg_color = '#282828',
            bg_color = '#fe8019',
            intensity = 'Bold',
        },
        inactive_tab = {
            fg_color = '#a89984',
            bg_color = '#3c3836',
        },
        inactive_tab_hover = {
            fg_color = '#fbf1c7',
            bg_color = '#504945',
        },
        new_tab = {
            fg_color = '#a89984',
            bg_color = '#282828',
        },
        new_tab_hover = {
            fg_color = '#fe8019',
            bg_color = '#3c3836',
        },
    }
}

-- Leader Key Setup (Ctrl + /)
config.leader = { key = "/", mods = "CTRL", timeout_milliseconds = 2000 }

-- Keybindings
config.keys = {
    -- Pane Splitting (Both Ctrl+Shift and Leader variants)
    { key = '"', mods = "CTRL|SHIFT", action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }) },
    { key = '%', mods = "CTRL|SHIFT", action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
    { key = '-', mods = "LEADER", action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }) },
    { key = '|', mods = "LEADER|SHIFT", action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }) },

    -- Pane Navigation (Leader + hjkl)
    { key = 'h', mods = 'LEADER', action = wezterm.action.ActivatePaneDirection('Left') },
    { key = 'j', mods = 'LEADER', action = wezterm.action.ActivatePaneDirection('Down') },
    { key = 'k', mods = 'LEADER', action = wezterm.action.ActivatePaneDirection('Up') },
    { key = 'l', mods = 'LEADER', action = wezterm.action.ActivatePaneDirection('Right') },

    -- Pane Management
    { key = 'x', mods = 'LEADER', action = wezterm.action.CloseCurrentPane({ confirm = true }) },
    { key = 'z', mods = 'LEADER', action = wezterm.action.TogglePaneZoomState },

    -- Tab Management
    { key = 'c', mods = 'LEADER', action = wezterm.action.SpawnTab('CurrentPaneDomain') },
    { key = ',', mods = 'LEADER', action = wezterm.action.PromptInputLine({
        description = 'Enter new name for tab',
        action = wezterm.action_callback(function(window, pane, line)
            if line then
                window:active_tab():set_title(line)
            end
        end),
    }) },

    -- Quick Tab Navigation (Leader + 1..9)
    { key = '1', mods = 'LEADER', action = wezterm.action.ActivateTab(0) },
    { key = '2', mods = 'LEADER', action = wezterm.action.ActivateTab(1) },
    { key = '3', mods = 'LEADER', action = wezterm.action.ActivateTab(2) },
    { key = '4', mods = 'LEADER', action = wezterm.action.ActivateTab(3) },
    { key = '5', mods = 'LEADER', action = wezterm.action.ActivateTab(4) },
    { key = '6', mods = 'LEADER', action = wezterm.action.ActivateTab(5) },
    { key = '7', mods = 'LEADER', action = wezterm.action.ActivateTab(6) },
    { key = '8', mods = 'LEADER', action = wezterm.action.ActivateTab(7) },
    { key = '9', mods = 'LEADER', action = wezterm.action.ActivateTab(8) },

    -- Color Scheme Selector (Leader + t)
    {
        key = 't',
        mods = 'LEADER',
        action = wezterm.action_callback(function(window, pane)
            local schemes = wezterm.color.get_builtin_schemes()
            local choices = {}
            for name, _ in pairs(schemes) do
                table.insert(choices, { label = name, id = name })
            end
            table.sort(choices, function(a, b)
                return a.label < b.label
            end)
            window:perform_action(
                wezterm.action.InputSelector({
                    title = 'Select Color Scheme',
                    choices = choices,
                    fuzzy = true,
                    action = wezterm.action_callback(function(win, p, id, label)
                        if id then
                            local overrides = win:get_config_overrides() or {}
                            overrides.color_scheme = id
                            win:set_config_overrides(overrides)
                        end
                    end),
                }),
                pane
            )
        end),
    },
}

-- Status Bar Update
local hostname = wezterm.hostname()

wezterm.on("update-status", function(window, pane)
    local palette = window:effective_config().resolved_palette
    local bg = palette.background or "#282828"
    local yellow = palette.ansi[4] or "#fabd2f"
    local fg = palette.foreground or "#ebdbb2"

    local leader = ""
    if window:leader_is_active() then
        leader = " LEAD "
    end

    window:set_right_status(wezterm.format({
        { Background = { Color = bg } },
        { Foreground = { Color = yellow } },
        { Attribute = { Intensity = "Bold" } },
        { Text = leader },
        { Foreground = { Color = fg } },
        { Attribute = { Intensity = "Normal" } },
        { Text = " " .. hostname .. " | " .. wezterm.strftime("%H:%M") .. " " },
    }))
end)

return config
