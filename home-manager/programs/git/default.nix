{ pkgs, ... }:
{
  # home.packages = options.home.packages.default ++ (with pkgs; [ lazygit ]);
  programs = {
    lazygit = {
      enable = true;
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
      userName = "Ali M";
      userEmail = "ali.mohamadza@gmail.com";
      # Install git with all the optional extras
      package = pkgs.gitAndTools.gitFull;
      aliases = {
        clone-bare = "!sh ${./git-clone-bare.sh}";
      };
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
    };
  };
}
