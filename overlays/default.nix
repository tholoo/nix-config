# This file defines overlays
{ inputs, ... }:
{
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs { pkgs = final; };

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: {
    keyd = prev.keyd.overrideAttrs (oldAttrs: rec {
      version = "2.4.3";
      src = final.fetchFromGitHub {
        owner = "rvaiya";
        repo = "keyd";
        rev = "02c77af7861a28927cc948d93e5477198bc0c933";
        hash = "sha256-rPxC+amLHUM39aX03KIWClgz4oHtQZiQI6svEL2AzHA=";
      };
      postPatch = ''
        substituteInPlace Makefile \
          --replace /usr/local ""

        substituteInPlace keyd.service.in \
          --replace @PREFIX@/bin $out/bin
      '';
    });
    # example = prev.example.overrideAttrs (oldAttrs: rec {
    # ...
    # });
  };

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  # unstable-packages = final: _prev: {
  # unstable = import inputs.nixpkgs-unstable {
  # system = final.system;
  # config.allowUnfree = true;
  # };
  # };
}
