{ inputs, channels, ... }:
final: prev: {
  wezterm = inputs.wezterm-nightly;
  # wezterm = prev.wezterm.overrideAttrs (oldAttrs: {
  #   version = "20240506";
  #   src = final.fetchFromGitHub {
  #     owner = "wez";
  #     repo = "wezterm";
  #     rev = "e4b18c41e650718b031dcc8ef0f93f23a1013aaa";
  #     fetchSubmodules = true;
  #     hash = "sha256-qLXiqA/K3PLLd+DMRXQDkXRsluCkBitIrYZ8xnm8LcE=";
  #   };
  #   cargoLock = {
  #     lockFile = ./Cargo.lock;
  #     # outputHashes = {
  #     #   "xcb-imdkit-0.3.0" = "sha256-fTpJ6uNhjmCWv7dZqVgYuS2Uic36XNYTbqlaly5QBjI=";
  #     # };
  #   };
  # });
}
