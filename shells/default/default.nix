{
  inputs,
  pkgs,
  mkShell,
  system,
  ...
}:

mkShell {
  packages = with pkgs; [
    deploy-rs
    inputs.agenix.packages.${system}.default
  ];
}
