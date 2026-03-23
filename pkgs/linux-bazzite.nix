{
  lib,
  fetchFromGitHub,
  linuxManualConfig,
  ...
}:

let
  pins = builtins.fromJSON (builtins.readFile ../pins.json);
  src = fetchFromGitHub {
    owner = "bazzite-org";
    repo = "kernel-bazzite";
    rev = pins.rev;
    hash = pins.srcHash;
  };
in

linuxManualConfig {
  inherit src lib;
  version = pins.version;
  modDirVersion = pins.version;

  # Use the kernel's default config as a base
  # allowImportFromDerivation lets Nix read the config at eval time
  configfile = "${src}/kernel-local";
  allowImportFromDerivation = true;

  extraMeta = {
    description = "Bazzite kernel - gaming and handheld optimized";
    branch = "bazzite-${lib.versions.major pins.version}";
  };
}