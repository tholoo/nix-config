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
  name = "git";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "cli-tools"
      "dev"
    ];
  };

  config = mkIf cfg.enable {
    programs = {
      lazygit = {
        enable = true;
        settings = {
          git = {
            log.showWholeGraph = true;
            paging.externalDiffCommand = "${lib.getExe pkgs.difftastic} --color=always";
          };
          gui = {
            theme = {
              selectedLineBgColor = [ "#2e2e2e" ];
            };
            nerdFontsVersion = "3";
          };
        };
      };
      gh = {
        enable = true;
        extensions = with pkgs; [ gh-copilot ];
        # git_protocol = "ssh";
      };
      gh-dash.enable = true;
      git-cliff.enable = true;
      git = {
        enable = true;
        userName = config.mine.user.fullName;
        userEmail = config.mine.user.email;
        # Install git with all the optional extras
        package = pkgs.gitAndTools.gitFull;
        delta.enable = true;
        # diff-so-fancy.enable = true;
        extraConfig = {
          core.editor = "nvim";
          init.defaultBranch = "main";
          pull.rebase = false;
          # Cache git credentials for 15 minutes
          credential.helper = "cache";
          # always use --update-refs
          rebase.updateRefs = true;
          # if branch exists in origin, git worktree add will use that branch instead of creating a new one
          worktree.guessRemote = true;
        };
        aliases = {
          a = "add";
          b = "branch";
          c = "commit";
          cb = "checkout -b";
          cm = "commit -m";
          co = "checkout";
          f = "fetch";
          s = "status -s";
          lg = "log --oneline --graph --decorate --all --abbrev-commit --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset'";
          clone-bare = "!${lib.getExe pkgs.bash} ${./git-clone-bare.sh}";
          info = "!${lib.getExe pkgs.onefetch}";
          done = "!${lib.getExe pkgs.bash} ${./git-done.sh}";
        };
      };
    };
  };
}
