{
  inputs,
  lib,
  pkgs,
}:

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
  localSkills = if builtins.pathExists ./skills then discoverSkills ./skills else { };
  packagedSkills = {
    tour = pkgs.mine.tour-skill;
  };
  duplicateNames =
    lib.intersectLists (lib.attrNames upstreamSkills) (lib.attrNames localSkills)
    ++ lib.intersectLists (lib.attrNames (upstreamSkills // localSkills)) (
      lib.attrNames packagedSkills
    );
in
assert lib.assertMsg (
  duplicateNames == [ ]
) "Duplicate shared skills: ${lib.concatStringsSep ", " duplicateNames}";
upstreamSkills // localSkills // packagedSkills
