{
  pkgs,
  lib,
  getNixFiles,
  flakeSelf,
  ...
}:
{
  imports = lib.lists.remove ./default.nix (getNixFiles ./.);
}
