{
  pkgs,
  lib,
  getNixFiles,
  flakeSelf,
  ...
}:
{
  imports = getNixFiles ./.;
}
