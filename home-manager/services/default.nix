{ getNixFiles, ... }:
{
  imports = getNixFiles ./.;
}