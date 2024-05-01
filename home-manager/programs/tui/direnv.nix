{ ... }:
{
  programs.direnv = {
    enable = true;
    config = {
      load_dotenv = true;
      hide_env_diff = true;
      disable_stdin = true;
      warn_timeout = "10s";
    };
    nix-direnv.enable = true;
  };
}
