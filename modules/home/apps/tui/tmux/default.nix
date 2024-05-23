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
  name = "tmux";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "tui-interactive"
    ];
  };

  config = mkIf cfg.enable {
    programs.tmux = {
      enable = true;
      baseIndex = 1;
      clock24 = true;
      historyLimit = 10000;
      keyMode = "vi";
      escapeTime = 0;
      customPaneNavigationAndResize = true;
      mouse = true;
      shell = "${pkgs.fish}/bin/fish";
      terminal = "screen-256color";
      shortcut = "b";
      extraConfig = # tmux
        ''
          # disable warnings when closing panes
          bind-key & kill-window
          bind-key x kill-pane

          bind T switchc -t 'terminal'

          bind | split-window -h # vertical split
          bind - split-window -v # horizontal split

          # Linux only
          bind -n WheelUpPane if-shell -F -t = "#{mouse_any_flag}" "send-keys -M" "if -Ft= '#{pane_in_mode}' 'send-keys -M' 'select-pane -t=; copy-mode -e; send-keys -M'"
          bind -n WheelDownPane select-pane -t= \; send-keys -M
          bind -n C-WheelUpPane select-pane -t= \; copy-mode -e \; send-keys -M
          bind -T copy-mode-vi    C-WheelUpPane   send-keys -X halfpage-up
          bind -T copy-mode-vi    C-WheelDownPane send-keys -X halfpage-down
          bind -T copy-mode-emacs C-WheelUpPane   send-keys -X halfpage-up
          bind -T copy-mode-emacs C-WheelDownPane send-keys -X halfpage-down

          # set-window-option -g mode-keys vi
          bind-key -T copy-mode-vi v send -X begin-selection
          bind-key -T copy-mode-vi V send -X select-line
          bind-key -T copy-mode-vi y send -X copy-pipe 'xclip -in -selection clipboard'
          # To copy, left click and drag to highlight text in yellow,
          # once you release left click yellow text will disappear and will automatically be available in clibboard
          # # Use vim keybindings in copy mode
          # setw -g mode-keys vi
          # Update default binding of `Enter` to also use copy-pipe
          unbind -T copy-mode-vi Enter
          bind-key -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "xclip -selection c"
          bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "xclip -in -selection clipboard"

          # setw -g pane-base-index 1
          set -g detach-on-destroy off     # don't exit from tmux when closing a session
          # set -g escape-time 0             # zero-out escape time delay
          # set -g history-limit 100000     # increase history size (from 2,000)
          set -g renumber-windows on       # renumber all windows when any window is closed
          set -g set-clipboard on          # use system clipboard
          set -g status-position top
          # set -g default-terminal "''${TERM}"
          # setw -g mouse on
          # setw -g mode-keys vi
          # set -g status-keys vi
          set -g pane-active-border-style 'fg=magenta,bg=default'
          set -g pane-border-style 'fg=brightblack,bg=default'
          set-option -g status-position top
          set-window-option -g status-position top

          set-window-option -g automatic-rename on
          set-option -g status-interval 5
          set-option -g automatic-rename on
          set-option -g automatic-rename-format '#{b:pane_current_path}'
          set-option -g automatic-rename-format "#{?#{==:#{pane_current_command},fish},#{b:pane_current_path},#{pane_current_command}}"

          # for zen mode
          set-option -g allow-passthrough on

          set-option -g set-titles on
          setw -g monitor-activity on

          set -g @sessionx-bind 'f'
          set -g @sessionx-window-mode 'on'

          set -g @continuum-restore 'on'
          set -g @resurrect-strategy-nvim 'session'

          set -g @minimal-tmux-bg "#36a3d9"
          set-option -g status-style bg=terminal,fg=terminal
          set-option -g status-justify centre
          set-option -g status-right '#[bg=default,fg=default,bold]#{?client_prefix,,     }#[bg=#{@minimal-tmux-bg},fg=black,bold]#{?client_prefix,     ,}'
          set-option -g status-left '#S'
          set-option -g window-status-format ' #I: #W '
          set-option -g window-status-current-format '#[bg=#{@minimal-tmux-bg},fg=#000000] #I: #W#{?window_zoomed_flag,  , }'

          # # Activate OFF mode
          # bind -n C-q \
          #   set prefix None \;\
          #   set key-table off \;\
          #   set status-style "fg=colour245,bg=colour238"
          #
          # # Disable OFF mode
          # bind -T off C-Q \
          #   set -u prefix \;\
          #   set -u key-table \;\
          #   set -u status-style
        '';

      plugins = with pkgs.tmuxPlugins; [
        # unsupported plugins
        # 'omerxx/tmux-sessionx'
        {
          plugin = session-wizard;
          extraConfig = # tmux
            ''
              set -g @session-wizard 't'
              set -g @session-wizard-height 80
              set -g @session-wizard-width 80
            '';
        }
        copy-toolkit
        {
          plugin = extrakto;
          extraConfig = # tmux
            ''
              set -g @extrakto_clip_tool 'wl-copy'
              set -g @extrakto_filter_order 'word line all'
            '';
        }

        yank
        # vim-tmux-navigator
        # {
        # plugin = resurrect;
        # extraConfig = "set -g @resurrect-strategy-nvim 'session'";
        # }
        # {
        # plugin = continuum;
        # extraConfig = ''
        # set -g @continuum-restore 'on'
        # set -g @continuum-save-interval '60' # minutes
        # '';
        # }
      ];
    };
  };
}
