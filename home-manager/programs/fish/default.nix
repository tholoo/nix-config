{ pkgs, ... }: {
  programs.fish = {
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

            if type -q $setxkbmap
              setxkbmap -option caps:escape
            end

      ### AUTOCOMPLETE AND HIGHLIGHT COLORS ###
            set fish_color_normal brcyan
            set fish_color_autosuggestion '#7d7d7d'
            set fish_color_command brcyan
            set fish_color_error '#ff6c6b'
            set fish_color_param brcyan
    '';
    functions = {
      fish_user_key_bindings = ''
        bind -M insert \cn down-or-search
        bind -M insert \cp up-or-search
        bind -M insert -k nul accept-autosuggestion
      '';

      __history_previous_command = ''
        switch (commandline -t)
            case "!"
                commandline -t $history[1]
                commandline -f repaint
            case "*"
                commandline -i !
            end
      '';

      __history_previous_command_arguments = ''
        switch (commandline -t)
            case "!"
                commandline -t ""
                commandline -f history-token-search-backward
            case "*"
                commandline -i '$'
            end
      '';

      multicd = ''
        echo cd (string repeat -n (math (string length -- $argv[1]) - 1) ../)
      '';

      ask = ''
        gh copilot suggest "$(read -l)"
      '';

      exp = ''
        gh copilot explain "$(read -l)"
      '';

      dot = ''
        set -l query (${pkgs.fd}/bin/fd . ~/dotfiles/ -t f -H -E .git | ${pkgs.fzf}/bin/fzf --layout reverse --preview "head {}")
        $EDITOR "$query"
      '';

      mkcd = ''
        mkdir $argv
        and cd $argv
      '';

      # try out packages
      try = {
        description =
          "spawn a new shell with the specified packages to try them out";
        wraps = "nix-shell";
        body = ''
          set cmd "nix-shell --command $SHELL"
          for arg in $argv
              set cmd "$cmd -p \"$arg\""
          end
          eval $cmd
        '';
      };
      # try out package and execute it
      trye = {
        description =
          "run and execute the specified package. an optional second argument as the command to be run can be provided";
        wraps = "nix-shell";
        argumentNames = [ "package" "command" ];
        body = ''
          set cmd "nix-shell --command $SHELL -p \"$package\""

          if test -n "$command"
              set cmd "$cmd --run \"$command\""
          else
              set cmd "$cmd --run \"$package\""
          end

          eval "$cmd"
        '';
      };
    };

    shellAbbrs = {
      df = "df -h"; # human-readable sizes
      free = "free -m"; # show sizes in MB

      # ps
      psa = "ps auxf";
      psgrep = "ps aux | grep -v grep | grep -i -e VSZ -e";
      psmem = "ps auxf | sort -nr -k 4";
      pscpu = "ps auxf | sort -nr -k 3";

      # Merge Xresources
      merge = "xrdb -merge ~/.Xresources";

      # git
      ga = "git add";
      gaa = "git add .";
      gb = "git branch";
      gco = "git checkout";
      gcl = "git clone";
      gc = "git commit -m";
      gf = "git fetch";
      pull = "git pull origin";
      push = "git push origin";
      gtag = "git tag";
      gnewtag = "git tag -a";
      gss = "git status -s";

      # get error messages from journalctl
      jctl = "journalctl -p 3 -xb";

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

      glog =
        "git log --oneline --graph --decorate --all --abbrev-commit --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset'";
      gcb = "git checkout -b";
    };
    shellAliases = {
      ls = "${pkgs.eza}/bin/eza --color=always --group-directories-first --git";
      la =
        "${pkgs.eza}/bin/eza -la --color=always --group-directories-first --git --git-ignore -I .venv -I __pycache__ -I .git";
      laa = "${pkgs.eza}/bin/eza -la --color=always --group-directories-first";
      ll =
        "${pkgs.eza}/bin/eza -l --color=always --group-directories-first --git -I .venv -I __pycache__ -I .git";
      lt =
        "${pkgs.eza}/bin/eza -l --tree --level=2 --color=always --group-directories-first -I .venv -I __pycache__ -I .git";
      ltt =
        "${pkgs.eza}/bin/eza -l --tree --color=always --group-directories-first -I .venv -I __pycache__ -I .git";
      lat =
        "${pkgs.eza}/bin/eza -la --tree --level=2 --color=always --group-directories-first -I .venv -I __pycache__ -I .git";
      latt =
        "${pkgs.eza}/bin/eza -la --tree --color=always --group-directories-first -I .venv -I __pycache__ -I .git";
      "l." = ''${pkgs.eza}/bin/eza -la | egrep "^\."'';

      grep = "grep --color=auto";
      egrep = "egrep --color=auto";
      fgrep = "fgrep --color=auto";

    };
    plugins = with pkgs.fishPlugins; [

      # Enable a plugin (here grc for colorized command output) from nixpkgs
      {
        name = "grc";
        src = grc.src;
      }
      {
        name = "sponge";
        src = sponge.src;
      }
      {
        name = "puffer";
        src = puffer.src;
      }

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
    ];
  };
}
