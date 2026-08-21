{ inputs, lib }:

let
  discoverSkills =
    root:
    lib.concatMapAttrs (
      name: type:
      if type != "directory" then
        { }
      else
        let
          directory = root + "/${name}";
        in
        if builtins.pathExists (directory + "/SKILL.md") then
          { ${name} = directory; }
        else
          discoverSkills directory
    ) (builtins.readDir root);

  upstreamSkills = discoverSkills (inputs.matt-pocock-skills + "/skills");
  localSkills = discoverSkills ./skills;
  duplicateNames = lib.intersectLists (lib.attrNames upstreamSkills) (lib.attrNames localSkills);
in
assert lib.assertMsg (
  duplicateNames == [ ]
) "Duplicate local and Matt Pocock skills: ${lib.concatStringsSep ", " duplicateNames}";
upstreamSkills // localSkills
