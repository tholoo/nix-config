{ pkgs, options, ... }: {
  # home.packages = options.home.packages.default ++ (with pkgs; [ lazygit ]);
  programs = {
    lazygit = { enable = true; };
    gh = {
      enable = true;
      extensions = [ ];
      # git_protocol = "ssh";
    };
    gh-dash.enable = true;
    git = {
      enable = true;
      userName = "Ali M";
      userEmail = "ali.mohamadza@gmail.com";
      # Install git with all the optional extras
      package = pkgs.gitAndTools.gitFull;
      # aliases = {
      # }
      delta.enable = true;
      # diff-so-fancy.enable = true;
      extraConfig = {
        core.editor = "nvim";
        init.defaultBranch = "main";
        pull.rebase = false;
        # Cache git credentials for 15 minutes
        credential.helper = "cache";
      };
    };
  };
}
