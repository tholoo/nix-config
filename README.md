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

```bash
nix build --print-out-paths --no-link '.#nixosConfigurations.granite.config.system.build.toplevel'
nix-tree '.#nixosConfigurations.granite.config.system.build.toplevel'
```

Repl:
```bash
nix --extra-experimental-features repl-flake repl . --show-trace
```

Generate specific output formats:
```bash
nix build .#nixosConfigurations.glacier.config.formats.iso
```

Convert a server to nixos using nixos-anywhere
```bash
nix run github:nix-community/nixos-anywhere -- --flake .#granite root@granite --build-on-remote
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
