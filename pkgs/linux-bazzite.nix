{
  lib,
  fetchFromGitHub,
  linuxManualConfig,
}:

let
  pins = builtins.fromJSON (builtins.readFile ../pins.json);

  src = fetchFromGitHub {
    owner = "bazzite-org";
    repo = "kernel-bazzite";
    rev = pins.rev;
    hash = pins.srcHash;
  };

  kernel = linuxManualConfig {
    inherit src lib;
    version = pins.version;
    modDirVersion = pins.version;
    allowImportFromDerivation = true;
    configfile = "${src}/kernel-x86_64-fedora.config";

    extraMeta = {
      description = "Bazzite kernel - gaming and handheld optimized";
      branch = "bazzite-${lib.versions.major pins.version}";
    };
  };
in

kernel.overrideAttrs (old: {
  # Remove nixpkgs's hardcoded randstruct patch which doesn't apply to
  # the bazzite kernel tree (bazzite already has its own version)
  patches = [];
})