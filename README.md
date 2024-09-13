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

## nixos
```bash
nixos-rebuild switch --flake . --accept-flake-config
```


## tips
Check the size with: 
```bash
nix-shell -p nix-tree.out --run nix-tree
```

Repl:
```bash
nix --extra-experimental-features repl-flake repl . --show-trace
```

Generate specific output formats:
```bash
nix build .#nixosConfigurations.glacier.config.formats.iso
```

## secrets
Get the public ip with:
```bash
ssh-keyscan <ip>
```
add it to ./secrets/secrets.nix and then
```bash
agenix --rekey
```

Create a secret file:
```bash
agenix -e secret.age
```
