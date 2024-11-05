{ channels, ... }:
final: prev: {
  # because broken in update
  _7zz = prev._7zz.override { useUasm = true; };
}
