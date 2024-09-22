{ lib, ... }:
{
  plugins.improved-search = {
    enable = true;
    keymaps = [
      {
        action = "stable_next";
        key = "n";
        mode = [
          "n"
          "x"
          "o"
        ];
      }
      {
        action = "stable_previous";
        key = "N";
        mode = [
          "n"
          "x"
          "o"
        ];
      }
      {
        action = "current_word";
        key = "!";
        mode = "n";
        options = {
          desc = "Search current word without moving";
        };
      }
      {
        action = "in_place";
        key = "!";
        mode = "x";
      }
      {
        action = "forward";
        key = "*";
        mode = "x";
      }
      {
        action = "backward";
        key = "#";
        mode = "x";
      }
      {
        action = "in_place";
        key = "|";
        mode = "n";
      }
    ];
  };
}
