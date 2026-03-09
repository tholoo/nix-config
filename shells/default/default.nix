{
  inputs,
  pkgs,
  mkShell,
  system,
  ...
}:

mkShell {
  packages = [
    inputs.deploy-rs.packages.${system}.deploy-rs
    inputs.agenix.packages.${system}.default
  ];
}
