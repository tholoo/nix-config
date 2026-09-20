{ inputs, pkgs, ... }:
let
  upstream =
    (import (inputs.tour-nvim + "/nix/package.nix") {
      inherit pkgs;
      src = inputs.tour-nvim;
    }).skill;
in
pkgs.runCommand "tour-skill-mcp" { nativeBuildInputs = [ pkgs.patch ]; } ''
  cp -R ${upstream} "$out"
  chmod -R u+w "$out"
  # Keep the upstream authoring/schema references, prefer our structured bridge.
  patch --batch --fuzz=0 -d "$out" -p1 < ${./structured-mcp.patch}
''
