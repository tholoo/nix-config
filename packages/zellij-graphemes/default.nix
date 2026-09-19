{ pkgs, ... }:
pkgs.zellij.override {
  zellij-unwrapped = pkgs.zellij-unwrapped.overrideAttrs (
    attrs: old: {
      version = "0.46.0";
      src = pkgs.fetchFromGitHub {
        owner = "tholoo";
        repo = "zellij";
        rev = "474ea0cef620c83d6ec05a7c28c7f80c4f63bbbb";
        hash = "sha256-8xBkw616EaVeJ9NnHxfYOfNbBQmIuqx7+9JbilttXQA=";
      };
      # Mirror the fork's uncommitted Unicode fix until it has a published revision.
      patches = (old.patches or [ ]) ++ [ ./unicode-graphemes.patch ];
      cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
        name = "zellij-graphemes-0.46.0";
        inherit (attrs) src patches;
        hash = "sha256-eyB2MLq4A1zLiTJlMkteEnVzT/xVA7/U93hYFaYcR5M=";
      };

      # Skip the expensive release-mode unit-test build; retain Nixpkgs'
      # installation checks (executable version and system libcurl linkage).
      doCheck = false;
      passthru = builtins.removeAttrs (old.passthru or { }) [ "updateScript" ];
    }
  );
}
