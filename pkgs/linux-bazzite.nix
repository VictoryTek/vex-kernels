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

  extraMeta = {
    description = "Bazzite kernel - gaming and handheld optimized";
    branch = "bazzite-${lib.versions.major pins.version}";
  };
})