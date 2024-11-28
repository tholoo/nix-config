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
  name = "password-store";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "password"
    ];
  };

  config = mkIf cfg.enable {
    programs.${name} = {
      enable = true;
      package = pkgs.pass-wayland.withExtensions (
        exts: with exts; [
          pass-otp
          pass-import
          pass-audit
        ]
      );
    };
    services.pass-secret-service.enable = true;
  };
}
