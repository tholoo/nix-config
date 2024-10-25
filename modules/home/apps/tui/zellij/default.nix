{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  inherit (config.lib.stylix) colors;
  cfg = config.mine.${name};
  name = "zellij";

  base00 = "282c34";
  base01 = "353b45";
  base02 = "3e4451";
  base03 = "545862";
  base04 = "565c64";
  base05 = "abb2bf";
  base06 = "b6bdca";
  base07 = "c8ccd4";
  base08 = "e06c75";
  base09 = "d19a66";
  base0A = "e5c07b";
  base0B = "98c379";
  base0C = "56b6c2";
  base0D = "61afef";
  base0E = "c678dd";
  base0F = "be5046";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "tui-interactive"
      "multiplexer"
    ];
  };

  config = mkIf cfg.enable {
    programs.zellij = {
      enable = true;
    };
    xdg.configFile."zellij/config.kdl".source = ./config.kdl;
    xdg.configFile."zellij/layouts/default.kdl".text = ''
      layout {
          default_tab_template {
              pane size=2 borderless=true {
                  plugin location="file://${pkgs.zjstatus}/bin/zjstatus.wasm" {
                      format_left   "{mode}#[bg=#${base00}] {tabs}"
                      format_center ""
                      format_right  "#[bg=#${base00},fg=#${base0D}]#[bg=#${base0D},fg=#${base01},bold] #[bg=#${base02},fg=#${base05},bold] {session} #[bg=#${base03},fg=#${base05},bold]"
                      format_space  ""
                      format_hide_on_overlength "true"
                      format_precedence "crl"

                      border_enabled  "false"
                      border_char     "─"
                      border_format   "#[fg=#6C7086]{char}"
                      border_position "top"

                      mode_normal        "#[bg=#${base0B},fg=#${base02},bold] NORMAL#[bg=#${base03},fg=#${base0B}]█"
                      mode_locked        "#[bg=#${base04},fg=#${base02},bold] LOCKED #[bg=#${base03},fg=#${base04}]█"
                      mode_resize        "#[bg=#${base08},fg=#${base02},bold] RESIZE#[bg=#${base03},fg=#${base08}]█"
                      mode_pane          "#[bg=#${base0D},fg=#${base02},bold] PANE#[bg=#${base03},fg=#${base0D}]█"
                      mode_tab           "#[bg=#${base07},fg=#${base02},bold] TAB#[bg=#${base03},fg=#${base07}]█"
                      mode_scroll        "#[bg=#${base0A},fg=#${base02},bold] SCROLL#[bg=#${base03},fg=#${base0A}]█"
                      mode_enter_search  "#[bg=#${base0D},fg=#${base02},bold] ENT-SEARCH#[bg=#${base03},fg=#${base0D}]█"
                      mode_search        "#[bg=#${base0D},fg=#${base02},bold] SEARCHARCH#[bg=#${base03},fg=#${base0D}]█"
                      mode_rename_tab    "#[bg=#${base07},fg=#${base02},bold] RENAME-TAB#[bg=#${base03},fg=#${base07}]█"
                      mode_rename_pane   "#[bg=#${base0D},fg=#${base02},bold] RENAME-PANE#[bg=#${base03},fg=#${base0D}]█"
                      mode_session       "#[bg=#${base0E},fg=#${base02},bold] SESSION#[bg=#${base03},fg=#${base0E}]█"
                      mode_move          "#[bg=#${base0F},fg=#${base02},bold] MOVE#[bg=#${base03},fg=#${base0F}]█"
                      mode_prompt        "#[bg=#${base0D},fg=#${base02},bold] PROMPT#[bg=#${base03},fg=#${base0D}]█"
                      mode_tmux          "#[bg=#${base09},fg=#${base02},bold] TMUX#[bg=#${base03},fg=#${base09}]█"

                      // formatting for inactive tabs
                      tab_normal              "#[bg=#${base03},fg=#${base0D}]█#[bg=#${base0D},fg=#${base02},bold]{index} #[bg=#${base02},fg=#${base05},bold] {name}{floating_indicator}#[bg=#${base03},fg=#${base02},bold]█"
                      tab_normal_fullscreen   "#[bg=#${base03},fg=#${base0D}]█#[bg=#${base0D},fg=#${base02},bold]{index} #[bg=#${base02},fg=#${base05},bold] {name}{fullscreen_indicator}#[bg=#${base03},fg=#${base02},bold]█"
                      tab_normal_sync         "#[bg=#${base03},fg=#${base0D}]█#[bg=#${base0D},fg=#${base02},bold]{index} #[bg=#${base02},fg=#${base05},bold] {name}{sync_indicator}#[bg=#${base03},fg=#${base02},bold]█"

                      // formatting for the current active tab
                      tab_active              "#[bg=#${base03},fg=#${base09}]█#[bg=#${base09},fg=#${base02},bold]{index} #[bg=#${base02},fg=#${base05},bold] {name}{floating_indicator}#[bg=#${base03},fg=#${base02},bold]█"
                      tab_active_fullscreen   "#[bg=#${base03},fg=#${base09}]█#[bg=#${base09},fg=#${base02},bold]{index} #[bg=#${base02},fg=#${base05},bold] {name}{fullscreen_indicator}#[bg=#${base03},fg=#${base02},bold]█"
                      tab_active_sync         "#[bg=#${base03},fg=#${base09}]█#[bg=#${base09},fg=#${base02},bold]{index} #[bg=#${base02},fg=#${base05},bold] {name}{sync_indicator}#[bg=#${base03},fg=#${base02},bold]█"

                      // separator between the tabs
                      tab_separator           "#[bg=#${base00}] "

                      // indicators
                      tab_sync_indicator       " "
                      tab_fullscreen_indicator " 󰊓"
                      tab_floating_indicator   " 󰹙"

                      command_git_branch_command     "git rev-parse --abbrev-ref HEAD"
                      command_git_branch_format      "#[fg=blue] {stdout} "
                      command_git_branch_interval    "10"
                      command_git_branch_rendermode  "static"

                      datetime        "#[fg=#6C7086,bold] {format} "
                      datetime_format "%A, %d %b %Y %H:%M"
                      datetime_timezone "Asia/Tehran"
                  }
              }
              children
          }
      }
    '';
  };
}
