let
  mkAll = attrs: attrs // { all = builtins.attrValues (builtins.removeAttrs attrs [ "all" ]); };

  users = mkAll {
    tholo = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDP5NAC+t7dRdeCUVaMPRUvfu4hrFLqEqpmh8NlXORwF";
    tholo_glacier = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM81VuTolmcvR3GSa5ZjcC2MQAD2l6EGgM44ZLo9Wp3U";
  };

  systems = mkAll {
    granite = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKpiDbSSUP7ePiyzluQojQgmIzDjBdTE3tCnP3dSJNIO";
    glacier = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM81VuTolmcvR3GSa5ZjcC2MQAD2l6EGgM44ZLo9Wp3U";
    ahm = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJrMl4Ne28Pl6LxsI/IsbSA4QK/wBzi/GfX4/jB/KbJt";
  };
in
{
  "ip-granite.age".publicKeys = users.all ++ systems.all;
  "ip-ahm.age".publicKeys = users.all ++ systems.all;
}
