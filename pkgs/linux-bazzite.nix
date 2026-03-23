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

    # Stub out missing akmod Kconfig files that are external modules
    # bazzite builds these separately as akmods; we just need empty stubs
    for kconfig in \
      drivers/custom/evdi/module/Kconfig \
      drivers/custom/v4l2loopback/Kconfig \
      drivers/custom/openrazer/Kconfig \
      drivers/custom/facecam/Kconfig \
      drivers/custom/nct6687d/Kconfig \
      drivers/custom/gcadapter_oc/Kconfig \
      drivers/custom/gpd-fan/Kconfig \
      drivers/custom/ryzen_smu/Kconfig \
      drivers/custom/zenergy/Kconfig \
      drivers/custom/xonedo/Kconfig; do
      mkdir -p "$(dirname $kconfig)"
      touch "$kconfig"
    done
  '' + (old.postPatch or "");

  extraMeta = {
    description = "Bazzite kernel - gaming and handheld optimized";
    branch = "bazzite-${lib.versions.major pins.version}";
  };
})