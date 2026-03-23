# Bazzite Kernel for NixOS

A Nix flake that packages the [Bazzite kernel](https://github.com/bazzite-org/kernel-bazzite) for NixOS.

## Usage

### As a Nix Flakes Input

Add this to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    vex-kernels.url = "github:VictoryTek/vex-kernels";
  };

  outputs = { self, nixpkgs, vex-kernels }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      nixosConfigurations.your-machine = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          vex-kernels.nixosModules.default
          ./configuration.nix
        ];
      };
    };
}
```

### Manual Installation

Build the kernel package:

```bash
nix build .#linux-bazzite
```

Access the kernel and headers:

```bash
nix-shell -p linux-bazzite
nix-shell -p linux-bazzite --run "echo $out"
```

## Kernel Version

Currently tracking Bazzite kernel version `6.17.7-ba28`.

## License

The Bazzite kernel is licensed under GPL-2.0.
