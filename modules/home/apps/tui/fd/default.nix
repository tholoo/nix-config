{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "fd";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "cli-tools"
    ];
  };

  config = mkIf cfg.enable {
    programs.fd = {
      enable = true;
      hidden = true;
      extraOptions = [ "--no-global-ignore-file" ];
      ignores = [
        ".DS_Store"
        ".cache/"
        ".direnv/"
        ".env/"
        ".git/"
        ".mypy_cache/"
        ".ruff_cache/"
        ".venv/"
        "__pycache__/"
        "node_modules/"
        "venv/"
      ];
    };
  };
}
