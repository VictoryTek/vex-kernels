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
in

linuxManualConfig {
  inherit src lib;
  version = pins.version;
  modDirVersion = pins.version;
  allowImportFromDerivation = true;

  # Use the x86_64 config shipped in the bazzite source tree
  configfile = "${src}/configs/kernel-x86_64-fedora.config";

  extraMeta = {
    description = "Bazzite kernel - gaming and handheld optimized";
    branch = "bazzite-${lib.versions.major pins.version}";
  };
}