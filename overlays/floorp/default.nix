{ channels, ... }:
final: prev: {
  floorp = channels.nixpkgs-stable.floorp;
}
