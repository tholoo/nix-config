{ pkgs, lib, ... }: {
  programs.chromium = {
    dictionaries = with pkgs; [ hunspellDictsChromium.en_US ];
    enable = true;
    extensions = [
      # Bypass Paywalls
      {
        id = "dcpihecpambacapedldabdbpakmachpb";
        updateUrl =
          "https://raw.githubusercontent.com/iamadamdev/bypass-paywalls-chrome/master/updates.xml";
      }
    ] ++ lib.fold (id: ids: [{ inherit id; }] ++ ids) [ ] [
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
      # SponserBlock
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
}
