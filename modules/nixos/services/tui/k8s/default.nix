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
  name = "k8s";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "service"
      "tui"
      "server"
    ];
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [
      6443 # k3s: required so that pods can reach the API server (running on port 6443 by default)
      # 2379 # k3s, etcd clients: required if using a "High Availability Embedded etcd" configuration
      # 2380 # k3s, etcd peers: required if using a "High Availability Embedded etcd" configuration
    ];
    networking.firewall.allowedUDPPorts = [
      # 8472 # k3s, flannel: required if using multi-node for inter-node networking
    ];
    services.k3s = {
      enable = true;
      role = "server";
      extraFlags = toString [
        "--node-label \"k3s-upgrade=false\""
        "--kube-apiserver-arg anonymous-auth=true"
        "--kube-controller-manager-arg bind-address=0.0.0.0"
        "--kube-scheduler-arg bind-address=0.0.0.0"
        "--etcd-expose-metrics"
        "--secrets-encryption"
        "--write-kubeconfig-mode 0644"
      ];
    };

    environment = {
      systemPackages = with pkgs; [
        fluxcd
      ];
      sessionVariables = {
        KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
      };
    };

    systemd = {
      timers."k3s-flux2-bootstrap" = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "3m";
          OnUnitActiveSec = "3m";
          Unit = "k3s-flux2-bootstrap.service";
        };
      };

      services = {
        "k3s-flux2-bootstrap" = {
          script = ''
            export PATH="$PATH:${pkgs.git}/bin"
            if ${lib.getExe pkgs.kubectl} get CustomResourceDefinition -A | grep -q "toolkit.fluxcd.io" ; then
              exit 0
            fi
            sleep 30
            if ${lib.getExe pkgs.kubectl} get CustomResourceDefinition -A | grep -q "toolkit.fluxcd.io" ; then
              exit 0
            fi
            mkdir -p /tmp/k3s-flux2-bootstrap
            cat > /tmp/k3s-flux2-bootstrap/kustomization.yaml << EOL
            apiVersion: kustomize.config.k8s.io/v1beta1
            kind: Kustomization
            resources:
              - github.com/fluxcd/flux2/manifests/install
            patches:
              # Remove the default network policies
              - patch: |-
                  \$patch: delete
                  apiVersion: networking.k8s.io/v1
                  kind: NetworkPolicy
                  metadata:
                    name: not-used
                target:
                  group: networking.k8s.io
                  kind: NetworkPolicy
            EOL
            ${lib.getExe pkgs.kubectl} apply --kustomize /tmp/k3s-flux2-bootstrap
          '';
          serviceConfig = {
            Type = "oneshot";
            User = "root";
            RestartSec = "3m";
          };
        };
      };
    };
  };
}
