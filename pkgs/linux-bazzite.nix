{
  lib,
  fetchFromGitHub,
  fetchurl,
  linuxManualConfig,
}:

let
  pins = builtins.fromJSON (builtins.readFile ../pins.json);

  bazzite = fetchFromGitHub {
    owner = "bazzite-org";
    repo = "kernel-bazzite";
    rev = pins.rev;
    hash = pins.srcHash;
  };

  src = fetchurl {
    url = "mirror://kernel/linux/kernel/v6.x/linux-${lib.versions.majorMinor pins.version}.${lib.versions.patch pins.version}.tar.xz";
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
  # Clear nixpkgs patches — bazzite's patches are applied manually below
  patches = [];

  postPatch = ''
    # Apply bazzite patches, allowing new files to be created
    for p in \
      ${bazzite}/patch-1-redhat.patch \
      ${bazzite}/patch-2-handheld.patch \
      ${bazzite}/patch-3-akmods.patch \
      ${bazzite}/patch-4-amdgpu-vrr-whitelist.patch; do
      echo "Applying $p"
      patch -p1 --forward --no-backup-if-mismatch < "$p" || true
    done
  '' + (old.postPatch or "");

  extraMeta = {
    description = "Bazzite kernel - gaming and handheld optimized";
    branch = "bazzite-${lib.versions.major pins.version}";
  };
})