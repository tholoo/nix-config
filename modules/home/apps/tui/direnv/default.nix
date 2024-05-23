{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "direnv";
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
  };
}
