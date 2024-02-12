{ config, pkgs, ... }@inputs:

{
  # imports = [
    # inputs.sops-nix.homeManagerModules.sops
    # agenix.homeManagerModules.default
  # ];

  home.username = inputs.username;
  home.homeDirectory = "/home/${inputs.username}";


  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "23.11"; # Please read the comment before changing.


  home.packages = with pkgs; [
    # essentials
    libgcc
    libgccjit
    clang

    # neovim
    nerdfonts
    vazir-fonts # persian font
    codespell

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')

    # nix related
    
    # it provides the command `nom` works just like `nix`
    # with more details log output
    nix-output-monitor

    # utils
    ripgrep # recursively searches directories for a regex pattern
    jq # A lightweight and flexible command-line JSON processor
    yq-go # yaml processer https://github.com/mikefarah/yq
    # eza # A modern replacement for ‘ls’
    # fzf # A command-line fuzzy finder
    fd # A rust alternative to find

    # archives
    zip
    xz
    unzip
    p7zip

    # productivity
    # hugo # static site generator
    glow # markdown previewer in terminal

    btop # replacement of htop/nmon
    iotop # io monitoring
    iftop # network monitoring

    # system call monitoring
    strace # system call monitoring
    ltrace # library call monitoring
    lsof # list open files

    # system tools
    sysstat
    lm_sensors # for `sensors` command
    ethtool
    pciutils # lspci
    usbutils # lsusb

    # languages
    lua

    python3
    poetry
  ];

  # link the configuration file in current directory to the specified location in home directory
  # home.file.".config/i3/wallpaper.jpg".source = ./wallpaper.jpg;

  # link all files in `./scripts` to `~/.config/i3/scripts`
  # home.file.".config/i3/scripts" = {
  #   source = ./scripts;
  #   recursive = true;   # link recursively
  #   executable = true;  # make all files executable
  # };


  # encode the file content in nix configuration file directly
  # home.file.".xxx".text = ''
  #     xxx
  # '';

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  # FIXME: temporary solution, should switch to nixvim
  home.file = {
    ".config/nvim" = {
      source = /home/tholo/dotfiles/nvim/.config/nvim;
      recursive = true;
    };
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. If you don't want to manage your shell through Home
  # Manager then you have to manually source 'hm-session-vars.sh' located at
  # either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/tholo/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    EDITOR = "nvim";
    SUDO_EDITOR = "nvim";
    VISUAL = "nvim";
    DIFFPROG = "nvim -d";
    MANPAGER = "nvim +Man!";


    # System
    # XDG_DATA_DIRS = "/usr/share:/usr/local/share"
    # XDG_CONFIG_DIRS = "/etc/xdg"
 
    # User
    # XDG_CACHE_HOME = "$HOME/.cache"
    # XDG_CONFIG_HOME = "$HOME/.config"
    # XDG_DATA_HOME = "$HOME/.local/share"
    # XDG_DESKTOP_DIR = "$HOME/Desktop"
    # XDG_DOWNLOAD_DIR = "$HOME/Downloads"
    # XDG_DOCUMENTS_DIR = "$HOME/Documents"
    # XDG_MUSIC_DIR = "$HOME/Music"
    # XDG_PICTURES_DIR = "$HOME/Pictures"
    # XDG_VIDEOS_DIR = "$HOME/Videos"
  };

  # wayland.windowManager.sway = {
    # enable = true;
    # xwayland = true;
  # };

  # Use sway desktop environment with Wayland display server
  # wayland.windowManager.sway = {
    # enable = true;
    # wrapperFeatures.gtk = true;
    # # Sway-specific Configuration
    # config = {
      # terminal = "alacritty";
      # menu = "wofi --show run";
      # # Status bar(s)
      # bars = [{
        # fonts.size = 15.0;
        # command = "waybar";
        # position = "bottom";
      # }];
      # # Display device configuration
      # output = {
        # eDP-1 = {
          # # Set HIDP scale (pixel integer scaling)
          # scale = "1";
        # };
      # };
    # };
  # };


  programs = {
    # Let Home Manager install and manage itself.
    home-manager.enable = true;

    git = {
      enable = true;
      userName = "Ali M";
      userEmail = "ali.mohamadza@gmail.com";
      # Install git wiith all the optional extras
      package = pkgs.gitAndTools.gitFull;
      # aliases = {
      # }
      delta.enable = true;
      diff-so-fancy.enable = true;
      extraConfig = {
        core.editor = "nvim";
        init.defaultBranch = "main";
        pull.rebase = false;
        # Cache git credentials for 15 minutes
        credential.helper = "cache";
      };
    };

    fish = {
      enable = true;
      interactiveShellInit = ''
        set fish_greeting # Disable greeting

        # Commands to run in interactive sessions can go here
        # ### SET EITHER DEFAULT EMACS MODE OR VI MODE ###
        # Emulates vim's cursor shape behavior
        # Set the normal and visual mode cursors to a block
        set fish_cursor_default block
        # Set the insert mode cursor to a line
        set fish_cursor_insert line
        # Set the replace mode cursors to an underscore
        set fish_cursor_replace_one underscore
        set fish_cursor_replace underscore
        # Set the external cursor to a line. The external cursor appears when a command is started.
        # The cursor shape takes the value of fish_cursor_default when fish_cursor_external is not specified.
        set fish_cursor_external line
        # The following variable can be used to configure cursor shape in
        # visual mode, but due to fish_cursor_default, is redundant here
        set fish_cursor_visual block
        function fish_user_key_bindings
            # fish_default_key_bindings
            # # Execute this once per mode that emacs bindings should be used in
            fish_default_key_bindings -M insert
            # Then execute the vi-bindings so they take precedence when there's a conflict.
            # Without --no-erase fish_vi_key_bindings will default to
            # resetting all bindings.
            # The argument specifies the initial mode (insert, "default" or visual).
            fish_vi_key_bindings --no-erase insert

            bind -M insert \cn down-or-search
            bind -M insert \cp up-or-search
            bind -M insert -k nul accept-autosuggestion

        end
        set -g fish_vi_force_cursor 1


        if not set -q TMUX
            if tmux has-session -t terminal
                # exec tmux attach-session -t terminal
                exec tmux attach-session
            else
                tmux new-session -s terminal
            end
        end

        # Functions needed for !! and !$
        function __history_previous_command
            switch (commandline -t)
                case "!"
                    commandline -t $history[1]
                    commandline -f repaint
                case "*"
                    commandline -i !
            end
        end

        function __history_previous_command_arguments
            switch (commandline -t)
                case "!"
                    commandline -t ""
                    commandline -f history-token-search-backward
                case "*"
                    commandline -i '$'
            end
        end



        if [ "$fish_key_bindings" = fish_vi_key_bindings ]
            bind -Minsert ! __history_previous_command
            bind -Minsert '$' __history_previous_command_arguments
        else
            bind ! __history_previous_command
            bind '$' __history_previous_command_arguments
        end

	### AUTOCOMPLETE AND HIGHLIGHT COLORS ###
        set fish_color_normal brcyan
        set fish_color_autosuggestion '#7d7d7d'
        set fish_color_command brcyan
        set fish_color_error '#ff6c6b'
        set fish_color_param brcyan
      '';
      functions = {
        fish_user_key_bindings=
          ''
            bind -M insert \cn down-or-search
            bind -M insert \cp up-or-search
            bind -M insert -k nul accept-autosuggestion
          '';

        __history_previous_command=
          ''
            switch (commandline -t)
                case "!"
                    commandline -t $history[1]
                    commandline -f repaint
                case "*"
                    commandline -i !
                end
          '';

        __history_previous_command_arguments=
          ''
            switch (commandline -t)
                case "!"
                    commandline -t ""
                    commandline -f history-token-search-backward
                case "*"
                    commandline -i '$'
                end
          '';

        multicd =
          ''
            echo cd (string repeat -n (math (string length -- $argv[1]) - 1) ../)
          '';

        ask =
          ''
            gh copilot suggest "$(read -l)"
          '';

        exp =
          ''
            gh copilot explain "$(read -l)"
          '';


        dot =
          ''
            set -l query (${pkgs.fd}/bin/fd . ~/dotfiles/ -t f -H -E .git | ${pkgs.fzf}/bin/fzf --layout reverse --preview "head {}")
            $EDITOR "$query"
          '';

        mkcd =
          ''
            mkdir $argv
            and cd $argv
          '';
      };

      shellAbbrs = {
        df = ''df -h''; # human-readable sizes
        free = ''free -m''; # show sizes in MB

        # ps
        psa = ''ps auxf'';
        psgrep = ''ps aux | grep -v grep | grep -i -e VSZ -e'';
        psmem = ''ps auxf | sort -nr -k 4'';
        pscpu = ''ps auxf | sort -nr -k 3'';

        # Merge Xresources
        merge = ''xrdb -merge ~/.Xresources'';

        # git
        ga = ''git add'';
        gaa = ''git add .'';
        gb = ''git branch'';
        gco = ''git checkout'';
        gcl = ''git clone'';
        gc = ''git commit -m'';
        gf = ''git fetch'';
        pull = ''git pull origin'';
        push = ''git push origin'';
        gtag = ''git tag'';
        gnewtag = ''git tag -a'';
        gss = ''git status -s'';

        # get error messages from journalctl
        jctl = ''journalctl -p 3 -xb'';



        # FIXME: doesn't seem to work with home-manager stable
        # "-C" = {
          # regex = "^\\.\\.+$";
          # position = "anywhere";
          # function = "multicd";
        # };

        # reload = ''source ~/.config/fish/config.fish'';
        # fishr = ''source ~/.config/fish/config.fish'';
        # fishc = ''vim ~/.config/fish/config.fish'';

        # restow = ''stow --restow --verbose --target ~'';

        glog = ''git log --oneline --graph --decorate --all --abbrev-commit --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset'';
        gcb = ''git checkout -b'';
      };
      shellAliases = {
        ls = ''eza --color=always --group-directories-first --git'';
        la = ''eza -la --color=always --group-directories-first --git --git-ignore -I .venv -I __pycache__ -I .git'';
        laa = ''eza -la --color=always --group-directories-first'';
        ll = ''eza -l --color=always --group-directories-first --git -I .venv -I __pycache__ -I .git'';
        lt = ''eza -l --tree --level=2 --color=always --group-directories-first -I .venv -I __pycache__ -I .git'';
        ltt = ''eza -l --tree --color=always --group-directories-first -I .venv -I __pycache__ -I .git'';
        lat = ''eza -la --tree --level=2 --color=always --group-directories-first -I .venv -I __pycache__ -I .git'';
        latt = ''eza -la --tree --color=always --group-directories-first -I .venv -I __pycache__ -I .git'';
        "l." = ''eza -la | egrep "^\."'';

        grep = ''grep --color=auto'';
        egrep = ''egrep --color=auto'';
        fgrep = ''fgrep --color=auto'';

      };
      # plugins = [
        # Enable a plugin (here grc for colorized command output) from nixpkgs
        # { name = "grc"; src = pkgs.fishPlugins.grc.src; }
        # Manually packaging and enable a plugin
        # {
          # name = "z";
          # src = pkgs.fetchFromGitHub {
            # owner = "jethrokuan";
            # repo = "z";
            # rev = "e0e1b9dfdba362f8ab1ae8c1afc7ccf62b89f7eb";
            # sha256 = "0dbnir6jbwjpjalz14snzd3cgdysgcs3raznsijd6savad3qhijc";
          # };
        # }
      # ];
    };

    pyenv = {
      enable = true;
      enableFishIntegration = true;
    };

    zoxide = {
      enable = true;
      enableFishIntegration = true;
    };

    # python formatter
    # ruff = {
      # enable = true;
    # };
    
    neovim = {
      enable = true;
      defaultEditor = true;
      withPython3 = true;
      withNodeJs = true;
      withRuby = true;
      # vimAlias = true;
      # extraConfig = ''
        # set number
        # syntax on
        # set shiftwidth=2
        # set tabstop=2
        # set expandtab
        # set smarttab
        # set clipboard+=unnamedplus 
      # '';
      # plugins = with pkgs.vimPlugins; [
        # vim-devicons
        # vim-nix
      # ];
    };

    tmux = {
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
      extraConfig = ''
        # disable warnings when closing panes
        bind-key & kill-window
        bind-key x kill-pane

        # bind t to terminal
        unbind t
        unbind T
        bind T switchc -t 'terminal'

        bind | split-window -h # vertical split
        bind - split-window -v # horizontal split

        # Linux only
        set -g mouse on
        bind -n WheelUpPane if-shell -F -t = "#{mouse_any_flag}" "send-keys -M" "if -Ft= '#{pane_in_mode}' 'send-keys -M' 'select-pane -t=; copy-mode -e; send-keys -M'"
        bind -n WheelDownPane select-pane -t= \; send-keys -M
        bind -n C-WheelUpPane select-pane -t= \; copy-mode -e \; send-keys -M
        bind -T copy-mode-vi    C-WheelUpPane   send-keys -X halfpage-up
        bind -T copy-mode-vi    C-WheelDownPane send-keys -X halfpage-down
        bind -T copy-mode-emacs C-WheelUpPane   send-keys -X halfpage-up
        bind -T copy-mode-emacs C-WheelDownPane send-keys -X halfpage-down

        # set-window-option -g mode-keys vi
        # bind-key -T copy-mode-vi v send -X begin-selection
        # bind-key -T copy-mode-vi V send -X select-line
        # bind-key -T copy-mode-vi y send -X copy-pipe 'xclip -in -selection clipboard'
        # To copy, left click and drag to highlight text in yellow, 
        # once you release left click yellow text will disappear and will automatically be available in clibboard
        # # Use vim keybindings in copy mode
        # setw -g mode-keys vi
        # Update default binding of `Enter` to also use copy-pipe
        # unbind -T copy-mode-vi Enter
        # bind-key -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "xclip -selection c"
        # bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "xclip -in -selection clipboard"

        # Act like vim
        # bind-key -T copy-mode-vi 'v' send -X begin-selection
        # bind-key -T copy-mode-vi 'y' send -X copy-selection

        # set -g base-index 1              # start indexing windows at 1 instead of 0
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

        set -g @minimal-tmux-bg "#36a3d9"
        set-option -g status-style bg=terminal,fg=terminal
        set-option -g status-justify centre
        set-option -g status-right '#[bg=default,fg=default,bold]#{?client_prefix,,     }#[bg=#{@minimal-tmux-bg},fg=black,bold]#{?client_prefix,     ,}'
        set-option -g status-left '#S'
        set-option -g window-status-format ' #I: #W '
        set-option -g window-status-current-format '#[bg=#{@minimal-tmux-bg},fg=#000000] #I: #W#{?window_zoomed_flag,  , }'
      '';

      plugins = with pkgs.tmuxPlugins; [
          # unsupported plugins
          # set -g @plugin 'omerxx/tmux-sessionx'
          # set -g @plugin '27medkamal/tmux-session-wizard'

          # fzf
          # fzf-url
          # yank
          vim-tmux-navigator
          # yank
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

    fzf = {
      enable = true;
      enableFishIntegration = true;
      tmux.enableShellIntegration = false;
    };

    eza = {
      enable = true;
      enableAliases = false;
      git = true;
      icons = true;
      extraOptions = [
        "--group-directories-first"
      ];
    };

    alacritty = {
      enable = true;
      settings = {
        env.TERM = "alacritty";
        window = {
          decorations = "full";
          title = "Alacritty";
          dynamic_title = true;
          class = {
            instance = "Alacritty";
            general = "Alacritty";
          };
        };
        font = {
          normal = {
            family = "monospace";
            style = "regular";
          };
          bold = {
            family = "monospace";
            style = "regular";
          };
          italic = {
            family = "monospace";
            style = "regular";
          };
          bold_italic = {
            family = "monospace";
            style = "regular";
          };
          size = 14.00;
        };
        colors = {
          primary = {
            background = "#1d1f21";
            foreground = "#c5c8c6";
          };
        };
      };
    };
    
    # gtk = {
      # enable = true;
      # theme.name = "adw-gtk3";
      # cursorTheme.name = "Bibata-Modern-Ice";
      # iconTheme.name = "GruvboxPlus";
    # };

    bat = {
      enable = true;
    };

    # starship - an customizable prompt for any shell
    starship = {
      enable = true;
      # settings = {
        # add_newline = false;
        # aws.disabled = true;
        # gcloud.disabled = true;
        # line_break.disabled = true;
      # };
    };

    ssh = {
      enable = true;
    };

    wezterm = {
      enable = true;
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

        config.color_scheme = "Atom"
        config.enable_tab_bar = false
        config.window_background_opacity = 0.93
        config.default_cwd = "~"

        -- config.font = wezterm.font 'JetBrainsMono Nerd Font'
        config.font = wezterm.font_with_fallback({
                {
                        family = "FiraCode Nerd Font",
                },
                {
                        family = "Vazirmatn",
                },
        })
        config.bold_brightens_ansi_colors = "BrightAndBold"
        config.underline_position = -3.5
        config.underline_thickness = 1
        config.window_decorations = "RESIZE" -- NONE | TITLE | RESIZE | INTEGRATED_BUTTONS
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

    rofi = {
      enable = true;
      terminal = "wezterm";
    };
  };

  xsession = {
    enable = true;
    windowManager = {
      i3 = {
        enable = true;
        config = {
          modifier = "Mod4";
          terminal = "wezterm"; 
          # switch to previous workspace by pressing this workspace's key again
          workspaceAutoBackAndForth = true;
          menu = "${pkgs.rofi}/bin/rofi -show drun";
          defaultWorkspace = "1";
          window = {
            hideEdgeBorders = "smart";
          };
        };
      };
    };
  };

  services = {
    # use headphone buttons to control volume
    mpris-proxy.enable = true;
  };
}
