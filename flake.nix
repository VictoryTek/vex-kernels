{
  description = "Bazzite kernel packaged for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      packages.${system} = {
        linux-bazzite = pkgs.callPackage ./pkgs/linux-bazzite.nix {};
        default = self.packages.${system}.linux-bazzite;
      };

      overlays.default = final: prev: {
        linux-bazzite = final.callPackage ./pkgs/linux-bazzite.nix {};
        linuxPackages-bazzite = final.linuxPackagesFor final.linux-bazzite;
      };

      nixosModules.default = { pkgs, lib, ... }: {
        boot.kernelPackages = lib.mkDefault (
          pkgs.linuxPackagesFor (pkgs.callPackage ./pkgs/linux-bazzite.nix {})
        );
      };
    };
}