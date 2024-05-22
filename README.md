# nix-config

## nix
using https://github.com/DeterminateSystems/nix-installer:
```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

## home-manager
```bash
nix run home-manager/master -- init --switch
```
or
```bash
nix run home-manager/master -- switch --flake .
```

