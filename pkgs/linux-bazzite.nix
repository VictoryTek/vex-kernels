{
  lib,
  fetchFromGitHub,
  buildLinux,
  ...
} @ args:

let
  pins = builtins.fromJSON (builtins.readFile ../pins.json);
in

buildLinux (args // {
  inherit (pins) version;
  modDirVersion = pins.version;

  src = fetchFromGitHub {
    owner = "bazzite-org";
    repo = "kernel-bazzite";
    rev = pins.rev;
    hash = pins.srcHash;
  };

  # Bazzite already includes its own patches — skip NixOS's extra kernel patches
  # which are written against vanilla kernel trees and conflict with bazzite's tree
  kernelPatches = [];

  extraMeta = {
    description = "Bazzite kernel - gaming and handheld optimized";
    branch = "bazzite-${lib.versions.major pins.version}";
  };
})