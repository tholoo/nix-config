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

  zellij-switch-script = ./zellij-switch.nu;
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
    home.packages = with pkgs; [
      zellij-switch
    ];

    programs.zellij = {
      enable = true;
      settings = {
        show_startup_tips = false;
      };
    };
    # xdg.configFile."zellij/config.kdl".source = ./config.kdl;
    xdg.configFile."zellij/plugins/monocle.wasm".source =
      "${pkgs.mine.zellij-monocle}/zellij-monocle.wasm";
    xdg.configFile."zellij/plugins/room.wasm".source = "${pkgs.mine.zellij-room}/zellij-room.wasm";

    xdg.configFile."zellij/config.kdl".text = ''
      // DEFAULT: https://github.com/zellij-org/zellij/blob/main/zellij-utils/assets/config/default.kdl

      default_shell "nu"

      plugins {
          compact-bar location="zellij:compact-bar"
      }

      // simplified_ui true
      pane_frames false

      themes {
          base16 {
              fg      "#D8D8D8"
              bg      "#3b3b3b"
              black   "#181818"
              red     "#AC4242"
              green   "#90A959"
              yellow  "#F4BF75"
              blue    "#6A9FB5"
              magenta "#AA759F"
              cyan    "#75B5AA"
              white   "#F8F8F8"
              orange  "#ffa066"
          }
      }

      // theme "base16"
      // default_layout "simple"
      copy_on_select true
      // theme "catppuccin-mocha"
      // theme "dracula"

      keybinds clear-defaults=true {
          normal {}
          locked {
              bind "Alt g" { SwitchToMode "Normal" ; }
          }
          resize {
              bind "Alt r"     { SwitchToMode "Normal" ; }
              bind "h" "Left"  { Resize "Increase Left" ; }
              bind "j" "Down"  { Resize "Increase Down" ; }
              bind "k" "Up"    { Resize "Increase Up" ; }
              bind "l" "Right" { Resize "Increase Right" ; }
              bind "H" { Resize "Decrease Left"; }
              bind "J" { Resize "Decrease Down"; }
              bind "K" { Resize "Decrease Up"; }
              bind "L" { Resize "Decrease Right"; }
              bind "=" "+" { Resize "Increase"; }
              bind "-" { Resize "Decrease"; }
          }
          pane {
              bind "Alt p"     { SwitchToMode "Normal" ; }
              bind "c"         { Clear ; }
              bind "e"         { TogglePaneEmbedOrFloating ; SwitchToMode "Normal" ; }
              bind "f"         { ToggleFocusFullscreen ; SwitchToMode "Normal" ; }
              bind "j" "Down"  { NewPane "Down" ; SwitchToMode "Normal" ; }
              bind "l" "Right" { NewPane "Right" ; SwitchToMode "Normal" ; }
              bind "n"         { NewPane ; SwitchToMode "Normal" ; }
              bind "p"         { SwitchFocus ; SwitchToMode "Normal" ; }
              bind "r"         { SwitchToMode "RenamePane" ; PaneNameInput 0 ; }
              bind "w"         { ToggleFloatingPanes ; SwitchToMode "Normal" ; }
              bind "x"         { CloseFocus ; SwitchToMode "Normal" ; }
              bind "z"         { TogglePaneFrames ; SwitchToMode "Normal" ; }
          }
          move {
              bind "Alt m"     { SwitchToMode "Normal"; }
              bind "h" "Left"  { MovePane "Left" ; }
              bind "j" "Down"  { MovePane "Down" ; }
              bind "k" "Up"    { MovePane "Up" ; }
              bind "l" "Right" { MovePane "Right" ; }
          }
          tab {
              bind "Alt t" { SwitchToMode "Normal" ; }
              bind "b"     { BreakPane; SwitchToMode "Normal" ; }
              bind "h"     { MoveTab "Left" ; }
              bind "l"     { MoveTab "Right" ; }
              bind "n"     { NewTab ; SwitchToMode "Normal" ; }
              bind "r"     { SwitchToMode "RenameTab" ; TabNameInput 0 ; }
              bind "x"     { CloseTab ; SwitchToMode "Normal" ; }

              bind "]" { BreakPaneRight; SwitchToMode "Normal"; }
              bind "[" { BreakPaneLeft; SwitchToMode "Normal"; }
          }
          scroll {
              bind "Alt s"    { SwitchToMode "Normal" ; }
              bind "d"        { HalfPageScrollDown ; }
              bind "u"        { HalfPageScrollUp ; }
              bind "j" "Down" { ScrollDown ; }
              bind "k" "Up"   { ScrollUp ; }
              bind "Home"     { ScrollToTop ; SwitchToMode "Normal" ; }
              bind "End"      { ScrollToBottom ; SwitchToMode "Normal" ; }
              bind "Ctrl d" { PageScrollDown ; }
              bind "Ctrl u"   { PageScrollUp ; }
              bind "s"        { SwitchToMode "EnterSearch" ; SearchInput 0 ; }
              bind "e" { EditScrollback; SwitchToMode "Normal"; }
          }
          search {
              bind "Alt s" { SwitchToMode "Normal" ; }
              bind "n"     { Search "down" ; }
              bind "p"     { Search "up" ; }
              bind "c"     { SearchToggleOption "CaseSensitivity" ; }
              bind "w"     { SearchToggleOption "Wrap" ; }
              bind "o"     { SearchToggleOption "WholeWord" ; }
          }
          entersearch {
              bind "Alt c" "Esc" { SwitchToMode "Scroll" ; }
              bind "Enter"       { SwitchToMode "Search" ; }
          }
          renametab {
              bind "Alt c" { SwitchToMode "Normal" ; }
              bind "Esc"   { UndoRenameTab ; SwitchToMode "Tab" ; }
          }
          renamepane {
              bind "Alt c" { SwitchToMode "Normal"; }
              bind "Esc" { UndoRenamePane; SwitchToMode "Pane"; }
          }
          session {
              bind "Alt o" { SwitchToMode "Normal" ; }
              bind "d"     { Detach ; }
              bind "o"     {
                  LaunchOrFocusPlugin "session-manager" {
                      floating true
                      move_to_focused_tab true
                  };
                  SwitchToMode "Normal"
              }
              bind "p" {
                  LaunchOrFocusPlugin "plugin-manager" {
                      floating true
                          move_to_focused_tab true
                  };
                  SwitchToMode "Normal"
              }
          }
          shared_except "locked" {
              bind "Alt g"             { SwitchToMode "Locked" ; }
              // bind "Alt q"             { Quit ; }

              bind "Alt h" "Alt Left"  { MoveFocusOrTab "Left" ; }
              bind "Alt l" "Alt Right" { MoveFocusOrTab "Right" ; }

              bind "Alt j" "Alt Down"  { MoveFocus "Down" ; }
              bind "Alt k" "Alt Up"    { MoveFocus "Up" ; }

              bind "Alt ["             { PreviousSwapLayout ; }
              bind "Alt ]"             { NextSwapLayout ; }

              bind "Alt f" { ToggleFloatingPanes; }
              bind "Alt b" { NewPane; }
              bind "Alt n" { NewTab ; }
              bind "Alt x" { CloseFocus; }

              // bind "Alt i" { MoveTab "Left"; }
              // bind "Alt o" { MoveTab "Right"; }

              bind "Alt =" "Alt +" { Resize "Increase"; }
              bind "Alt -" { Resize "Decrease"; }

              bind "Alt d" {
                  LaunchPlugin "filepicker" {
                      // floating true
                      close_on_selection true
                  };
              }

              bind "Alt o" {
                  LaunchOrFocusPlugin "session-manager" {
                      floating true
                      move_to_focused_tab true
                  };
                  SwitchToMode "Normal"
              }

              bind "Alt i" {
                Run "zellij" "run" "--floating" "--close-on-exit" "--" "${zellij-switch-script}" {
                  close_on_exit true
                }
              }

              // open monocle in a new floating pane and open any results in a new tiled/floating pane
              bind "Alt '" {
                  LaunchOrFocusPlugin "file:~/.config/zellij/plugins/monocle.wasm" {
                      floating true
                  };
                  SwitchToMode "Normal"
              }
              // open monocle on top of the current pane and open any results on top of itself
              bind "Alt ;" {
                  LaunchPlugin "file:~/.config/zellij/plugins/monocle.wasm" {
                      in_place true
                      kiosk true
                  };
                  SwitchToMode "Normal"
              }

              // open room
              bind "Alt space" {
                  LaunchOrFocusPlugin "file:~/.config/zellij/plugins/room.wasm" {
                      floating true
                      ignore_case true
                      quick_jump true
                  }
              }

              bind "Alt 1"     { GoToTab 1 ; SwitchToMode "Normal" ; }
              bind "Alt 2"     { GoToTab 2 ; SwitchToMode "Normal" ; }
              bind "Alt 3"     { GoToTab 3 ; SwitchToMode "Normal" ; }
              bind "Alt 4"     { GoToTab 4 ; SwitchToMode "Normal" ; }
              bind "Alt 5"     { GoToTab 5 ; SwitchToMode "Normal" ; }
              bind "Alt 6"     { GoToTab 6 ; SwitchToMode "Normal" ; }
              bind "Alt 7"     { GoToTab 7 ; SwitchToMode "Normal" ; }
              bind "Alt 8"     { GoToTab 8 ; SwitchToMode "Normal" ; }
              bind "Alt 9"     { GoToTab 9 ; SwitchToMode "Normal" ; }
          }
          shared_except "normal" "locked" {
              bind "Enter" "Esc" { SwitchToMode "Normal" ; }
          }
          shared_except "pane" "locked" {
              bind "Alt p" { SwitchToMode "Pane" ; }
          }
          shared_except "resize" "locked" {
              bind "Alt r" { SwitchToMode "Resize" ; }
          }
          shared_except "scroll" "locked" {
              bind "Alt s" { SwitchToMode "Scroll" ; }
          }
          // shared_except "session" "locked" {
          //     bind "Alt o" { SwitchToMode "Session" ; }
          // }
          shared_except "tab" "locked" {
              bind "Alt t" { SwitchToMode "Tab" ; }
          }
          shared_except "move" "locked" {
              bind "Alt m" { SwitchToMode "Move" ; }
          }
      }

    '';
  };
}
