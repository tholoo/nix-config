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
  name = "chromium";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "browser"
      "web"
    ];
  };

  config = mkIf cfg.enable {
    programs.chromium = {
      enable = false;
      dictionaries = with pkgs; [ hunspellDictsChromium.en_US ];
      extensions =
        [
          # Bypass Paywalls
          {
            id = "dcpihecpambacapedldabdbpakmachpb";
            updateUrl = "https://raw.githubusercontent.com/iamadamdev/bypass-paywalls-chrome/master/src/updates/updates.xml";
          }
        ]
        ++ map (id: { inherit id; }) [
          # UBlock Origin
          "cjpalhdlnbpafiamejdnhcphjbkeiagm"
          # Global Speed
          "jpbjcnkcffbooppibceonlgknpkniiff"
          # Bitwarden
          "nngceckbapebfimnlniiiahkandclblb"
          # Dark Reader
          "eimadpbcbfnmbkopoojfekhnkhdbieeh"
          # TamperMonkey
          "dhdgffkkebhmkfjojejmpbldmpobfkfo"
          # I still don't care about cookies
          "edibdbjcniadpccecjdfdjjppcpchdlm"
          # FastForward
          "icallnadddjmdinamnolclfjanhfoafe"
          # SponsorBlock
          "mnjggcdmjocbbbhaepdhchncahnbgone"
          # Surfingkeys
          "gfbliohnnapiefjpjlpjnehglfpaknnc"
          # Search by Image
          "cnojnbdhbhnkbcieeekonklommdnndci"
          # Material Icons for Github
          "bggfcpfjbdkhfhfmkjpbhnkhnpjjeomc"
          # Proxy SwitchyOmega
          "padekgcemlokbadohgkifijomclgjgif"
        ];
    };
  };
}
