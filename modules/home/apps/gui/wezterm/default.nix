{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "wezterm";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "terminal"
    ];
  };

  config = mkIf cfg.enable {
    programs.wezterm = {
      enable = config.mine.terminal.emulator == name;
      extraConfig = ''
        -- Pull in the wezterm API
        local wezterm = require("wezterm")

        -- This table will hold the configuration.
        local config = {}

        -- In newer versions of wezterm, use the config_builder which will
        -- help provide clearer error messages
        if wezterm.config_builder then
                config = wezterm.config_builder()
        end

        local function is_vim(pane)
                -- this is set by the plugin, and unset on ExitPre in Neovim
                return pane:get_user_vars().IS_NVIM == "true"
        end

        config.initial_rows = 25
        config.initial_cols = 100
        config.scrollback_lines = 10000

        config.enable_tab_bar = false
        -- config.default_cwd = "~"

        config.font = wezterm.font_with_fallback({
          {
            family = "${config.stylix.fonts.monospace.name}",
          },
          {
            family = "Vazir Code Hack",
          },
        })
        config.bold_brightens_ansi_colors = "BrightAndBold"
        config.underline_position = -3.5
        config.underline_thickness = 1
        config.window_decorations = "NONE" -- NONE | TITLE | RESIZE | INTEGRATED_BUTTONS
        config.audible_bell = "Disabled"
        -- config.default_cursor_style = "BlinkingBar"
        -- config.cursor_blink_ease_in = "Constant"
        -- config.cursor_blink_ease_out = "Constant"
        -- config.cursor_blink_rate = 700

        config.line_height = 1.3
        -- config.cell_width = 0.95
        config.font_size = 12.5

        config.bidi_enabled = true
        config.bidi_direction = "AutoLeftToRight"

        -- Keep the session-level systemd SSH agent socket. WezTerm's default
        -- per-process symlink can become stale when a terminal process exits.
        config.mux_enable_ssh_agent = false

        -- A WezTerm window launched from inside Zellij must start a fresh
        -- shell context so Nushell's Zellij auto-start is not suppressed.
        config.mux_env_remove = {
          "SSH_AUTH_SOCK",
          "SSH_CLIENT",
          "SSH_CONNECTION",
          "ZELLIJ",
          "ZELLIJ_PANE_ID",
          "ZELLIJ_SESSION_NAME",
        }

        config.window_close_confirmation = "NeverPrompt"

        local direction_keys = {
                Left = "h",
                Down = "j",
                Up = "k",
                Right = "l",
                -- reverse lookup
                h = "Left",
                j = "Down",
                k = "Up",
                l = "Right",
        }

        config.window_padding = {
                left = 0, -- 15,
                right = 0, -- 15,
                top = 0,
                bottom = 0,
        }

        -- config.background = {
        -- 	{
        -- 		source = {
        -- 			File = "wallhaven-858z32_3840x2160.png",
        -- 		},
        -- 		hsb = { saturation = 0.9, brightness = 0.1 },
        -- 		-- opacity = 0.5,
        -- 		height = "100%",
        -- 		width = "100%",
        -- 	},
        -- }

        -- Integration with zen-mode
        wezterm.on("user-var-changed", function(window, pane, name, value)
                local overrides = window:get_config_overrides() or {}
                if name == "ZEN_MODE" then
                        local incremental = value:find("+")
                        local number_value = tonumber(value)
                        if incremental ~= nil then
                                while number_value > 0 do
                                        window:perform_action(wezterm.action.IncreaseFontSize, pane)
                                        number_value = number_value - 1
                                end
                        elseif number_value < 0 then
                                window:perform_action(wezterm.action.ResetFontSize, pane)
                                overrides.font_size = nil
                        else
                                overrides.font_size = number_value
                        end
                end
                window:set_config_overrides(overrides)
        end)

        return config
      '';
    };
  };
}
