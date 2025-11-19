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
            pagers = [
              { externalDiffCommand = "${lib.getExe pkgs.difftastic} --color=always"; }
            ];
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
      delta = {
        enable = true;
        enableGitIntegration = true;
      };
      git = {
        enable = true;
        lfs.enable = true;
        # diff-so-fancy.enable = true;
        settings = {
          core.editor = "hx";
          init.defaultBranch = "main";
          pull.rebase = true;
          rebase.autostash = true;
          # Cache git credentials for 15 minutes
          credential.helper = "cache";
          # always use --update-refs
          rebase.updateRefs = true;
          # if branch exists in origin, git worktree add will use that branch instead of creating a new one
          worktree.guessRemote = true;

          user = {
            name = config.mine.user.fullName;
            email = config.mine.user.email;
          };
          alias = {
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
            mr = "!sh -c 'git fetch $1 merge-requests/$2/head:mr-$1-$2 && git checkout mr-$1-$2' -";
          };
        };
      };
    };
  };
}
