let
  mkAll = attrs: attrs // { all = builtins.attrValues (builtins.removeAttrs attrs [ "all" ]); };

  users = mkAll {
    tholo = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDP5NAC+t7dRdeCUVaMPRUvfu4hrFLqEqpmh8NlXORwF";
    tholo_work = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDb3wbU6SiU7K7WLRt2WuttDWblL6+JW7vD4tJpY659Z";
    tholo_glacier = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAafNwMxYz3xz32eVjBeoETp+VQuOnBgPTvvxeFP0qpT";
  };

  systems = mkAll {
    granite = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKpiDbSSUP7ePiyzluQojQgmIzDjBdTE3tCnP3dSJNIO";
    glacier = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPyemf0UBtGui3lF6WEeJ2s/3J9ok4FBohEO1TzEWmb3";
  };
in
{
  "ip-tholo-tech.age".publicKeys = users.all ++ systems.all;
}
