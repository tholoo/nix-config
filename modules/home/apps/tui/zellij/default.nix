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

  zellij-switch = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "zellij-switch";
    name = pname;

    executable = pkgs.fetchurl {
      url = "https://github.com/mostafaqanbaryan/zellij-switch/releases/download/v0.1.1/zellij-switch.wasm";
      hash = "sha256-jLzpmFzzNL3m5q8u4fgB+NOti5nAPOpaESAhEaxTm5E";
    };

    phases = [ "installPhase" ]; # Removes all phases except installPhase

    dontBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp $executable $out/zellij-switch.wasm
      runHook postInstall
    '';
  };

  zellij-switch-script = pkgs.writeShellScript "zellij-switch-script" (''
    if [ "$(command -v zellij)" = "" ]; then
        echo "Zellij is not installed"
        exit 1
    fi

    home_replacer() {
        HOME_REPLACER=""                                          # default to a noop
        echo "$HOME" | grep -E "^[a-zA-Z0-9\-_/.@]+$" &>/dev/null # chars safe to use in sed
        HOME_SED_SAFE=$?
        if [ $HOME_SED_SAFE -eq 0 ]; then # $HOME should be safe to use in sed
            HOME_REPLACER="s|^$HOME/|~/|"
        fi
        echo "$HOME_REPLACER"
    }

    transform_home_path() {
        HOME_SED_SAFE=$?
        if [ $HOME_SED_SAFE -eq 0 ]; then
            echo "$1" | sed -e "s|^~/|$HOME/|"
        else
            echo "$1"
        fi
    }

    fzf_window() {
    	fzf --reverse --no-sort --border "rounded" --info inline --pointer "→" --prompt "Session > " --header "Select session" --preview "echo {2} | grep -q 'Session' && echo {} || ls {3}"
    }

    select_project() {
    	list=$(find ~/projects/ -maxdepth 1 -type d)
      project_dir=$({ zellij list-sessions -s | awk '{ print "("NR")\t[Session]\t"$1 }'; echo $list | tr --truncate-set1 " /" "\n" | awk '{ print "("NR")\t[Directory]\t"$1 }' ; } | fzf_window)
      if [ "$project_dir" = "" ]; then
          exit
      fi
    	echo "$project_dir"
    }

    is_selected_session(){
    	if [ -n "$(echo "$1" | grep "^([0-9]*)\\\t\[Session\]")" ]; then
    		echo 1
    	fi
    }

    get_sanitized_selected(){
    	echo "$1" | sed "s/^([0-9]*)\t\[[^]]*\]\t//"
    }

    get_session_name() {
        project_dir=$1
        directory=$(basename "$project_dir")
        session_name=$(echo "$directory" | tr ' .:' '_')
        echo "$session_name"
    }

    if [[ -n "$1" ]]; then
    	selected=$(realpath $1)
    else
    	selected=$(select_project)
    fi

    if [ -z "$selected" ]; then
    	exit 0
    fi

    is_session=$(is_selected_session "$selected")
    cwd=$(get_sanitized_selected "$selected")
    session_name=$(get_session_name "$(transform_home_path "$cwd")")
    session=$(zellij list-sessions | grep "$session_name")

    # If we're inside of zellij, detach
    if [[ -n "$ZELLIJ" ]]; then
    	zellij pipe --plugin file://${zellij-switch}/zellij-switch.wasm -- "$session_name::$cwd"
    elsjjke
    	if [[ -n "$session" ]]; then
    		zellij attach $session_name -c
    	else
    		zellij attach $session_name -c options --default-cwd $cwd
    	fi
    fi
  '');

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
    # xdg.configFile."zellij/config.kdl".source = ./config.kdl;
    xdg.configFile."zellij/config.kdl".text = ''
      // DEFAULT: https://github.com/zellij-org/zellij/blob/main/zellij-utils/assets/config/default.kdl

      default_shell "fish"

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
