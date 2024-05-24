  username,

  home-manager = {
    extraSpecialArgs = {
      inherit username;
    };
    users.${username} = import ./home.nix;
  };
}
