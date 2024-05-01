{
  pkgs,
  lib,
  getNixFiles,
  ...
}:
{
  imports = lib.lists.remove ./default.nix (getNixFiles ./.);
}
