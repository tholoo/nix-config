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
  name = "opengl";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "graphics"
    ];
  };

  config = mkIf cfg.enable {
    nixpkgs.config.packageOverrides = pkgs: {
      intel-vaapi-driver = pkgs.intel-vaapi-driver.override { enableHybridCodec = true; };
    };

    hardware.graphics = {
      enable = true;
      extraPackages32 = with pkgs.pkgsi686Linux; [ intel-vaapi-driver ];
      # driSupport = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        intel-media-driver # LIBVA_DRIVER_NAME=iHD
        intel-vaapi-driver # LIBVA_DRIVER_NAME=i965 (older but works better for Firefox/Chromium)
        libvdpau-va-gl
      ];
    };

    environment.sessionVariables = {
      LIBVA_DRIVER_NAME = "iHD";
    }; # Force intel-media-driver
  };
}
