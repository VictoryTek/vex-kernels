{
  lib,
  fetchFromGitHub,
  fetchurl,
  linuxManualConfig,
  buildPackages,
}:

let
  pins = builtins.fromJSON (builtins.readFile ../pins.json);

  # The bazzite repo is a packaging repo — it doesn't contain kernel source.
  # We need to fetch the actual vanilla kernel tarball and apply bazzite's patches.
  bazzite = fetchFromGitHub {
    owner = "bazzite-org";
    repo = "kernel-bazzite";
    rev = pins.rev;
    hash = pins.srcHash;
  };

  # Vanilla kernel source matching the bazzite version (6.17.7)
  src = fetchurl {
    url = "mirror://kernel/linux/kernel/v6.x/linux-6.17.7.tar.xz";
    hash = pins.kernelHash;
  };

  kernel = linuxManualConfig {
    inherit src lib;
    version = pins.version;
    modDirVersion = pins.version;
    allowImportFromDerivation = true;
    configfile = "${bazzite}/kernel-x86_64-fedora.config";
  };
in

kernel.overrideAttrs (old: {
  # Apply bazzite's patches on top of vanilla kernel source
  patches = [
    "${bazzite}/patch-1-redhat.patch"
    "${bazzite}/patch-2-handheld.patch"
    "${bazzite}/patch-3-akmods.patch"
    "${bazzite}/patch-4-amdgpu-vrr-whitelist.patch"
  ];

  extraMeta = {
    description = "Bazzite kernel - gaming and handheld optimized";
    branch = "bazzite-${lib.versions.major pins.version}";
  };
})