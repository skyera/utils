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
-- config.color_scheme = "Dracula"
config.font = wezterm.font_with_fallback({
    'JetBrains Mono',
    'Hack Nerd Font',
})
config.font_size = 10.0

-- Hide the title bar (cleaner look on macOS/Linux)
config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"

-- Enable the tab bar
config.enable_tab_bar = true
-- Hide the tab bar if there's only one tab
config.hide_tab_bar_if_only_one_tab = true
config.keys = {
    -- Split horizontally (top/bottom)
    {key="%", mods="CTRL|SHIFT", action=wezterm.action.SplitVertical{domain="CurrentPaneDomain"}},
    -- Split vertically (left/right)
    {key='"', mods="CTRL|SHIFT", action=wezterm.action.SplitHorizontal{domain="CurrentPaneDomain"}},
}

function tab_title(tab_info)
  local title = tab_info.tab_title
  -- if the tab title is explicitly set, take that
  if title and #title > 0 then
    return title
  end
  -- Otherwise, use the title from the active pane
  -- in that tab
  return tab_info.active_pane.title
end

wezterm.on(
  'format-tab-title',
  function(tab, tabs, panes, config, hover, max_width)
    local title = tab_title(tab)
    if tab.is_active then
      return {
        { Background = { Color = 'blue' } },
        { Text = ' ' .. title .. ' ' },
      }
    end
    if tab.is_last_active then
      -- Green color and append '*' to previously active tab.
      return {
        { Background = { Color = 'green' } },
        { Text = ' ' .. title .. '*' },
      }
    end
    return title
  end
)


return config

