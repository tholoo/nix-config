let
  mkAll = attrs: attrs // { all = builtins.attrValues (builtins.removeAttrs attrs [ "all" ]); };

  users = mkAll {
    tholo = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDP5NAC+t7dRdeCUVaMPRUvfu4hrFLqEqpmh8NlXORwF";
    tholo_work = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDb3wbU6SiU7K7WLRt2WuttDWblL6+JW7vD4tJpY659Z";
  };

  systems = mkAll {
    hetzner = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKpiDbSSUP7ePiyzluQojQgmIzDjBdTE3tCnP3dSJNIO";
  };
in
{
  "ip-tholo-tech.age".publicKeys = users.all ++ systems.all;
}
