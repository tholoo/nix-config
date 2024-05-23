{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "nvidia";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "gpu"
      "nvidia"
    ];
  };

  config = mkIf cfg.enable {
    # hardware = {
    # gt 710
    # nvidia = {
    #   package = config.boot.kernelPackages.nvidiaPackages.legacy_470;
    #   # Modesetting is required.
    #   modesetting.enable = true;
    #   # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    #   # Enable this if you have graphical corruption issues or application crashes after waking
    #   # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead
    #   # of just the bare essentials.
    #   powerManagement.enable = false;
    #
    #   # Fine-grained power management. Turns off GPU when not in use.
    #   # Experimental and only works on modern Nvidia GPUs (Turing or newer).
    #   powerManagement.finegrained = false;
    #
    #   # Use the NVidia open source kernel module (not to be confused with the
    #   # independent third-party "nouveau" open source driver).
    #   # Support is limited to the Turing and later architectures. Full list of
    #   # supported GPUs is at:
    #   # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
    #   # Only available from driver 515.43.04+
    #   # Currently alpha-quality/buggy, so false is currently the recommended setting.
    #   open = false;
    #
    #   # Enable the Nvidia settings menu,
    #   # accessible via `nvidia-settings`.
    #   nvidiaSettings = true;
    # };
    # pulseaudio = {
    #   enable = true;
    #   # extra codecs
    #   package = pkgs.pulseaudioFull;
    #   # automatically switch sound to bluetooth device
    #   extraConfig = "load-module module-switch-on-connect";
    # };
    # };
  };
}
