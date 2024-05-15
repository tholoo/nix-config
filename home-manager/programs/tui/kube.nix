{ pkgs, ... }:
{
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
}
