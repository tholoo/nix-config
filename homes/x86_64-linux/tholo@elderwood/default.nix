{
  lib,
  pkgs,
  inputs,
  virtual, # A boolean to determine whether this home is a virtual target using nixos-generators.
  host, # The host name for this home.
  config,
  ...
}:
{
  mine = {
    user = {
      name = "tholo";
      fullName = "tholo";
      email = "ali.mohamadza@gmail.com";
    };
    tags.exclude = [
      "gui"
      "game"
      "calender"
      "develop"
    ];

    gui.enable = false;
    tui.enable = true;

    claude-code.enable = false;
  };
}
