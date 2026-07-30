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
      settings = { };
      package = pkgs.pass-wayland.withExtensions (
        exts: with exts; [
          pass-otp
          pass-import
          pass-audit
        ]
      );
    };
    services.pass-secret-service.enable = true;

    # Do not fail every login before a password store has been initialized.
    systemd.user.services."pass-secret-service".Unit.ConditionPathExists =
      "%h/.password-store/.gpg-id";
  };
}
