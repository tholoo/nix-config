{ ... }: {
  programs.direnv = {
    enable = true;
    config = {
      load_dotenv = true;
      hide_env_diff = true;
    };
    nix-direnv.enable = true;
  };
}
