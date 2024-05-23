{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "kube";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "deploy"
      "container"
    ];
  };

  config = mkIf cfg.enable {
    programs.k9s.enable = true;
    home.packages = with pkgs; [
      kubectl
      kubelogin
      kubelogin-oidc
      kubernetes-helm
      kubeseal
      kubectx
      kns
      kubie
      krew
      minikube
    ];
  };
}
