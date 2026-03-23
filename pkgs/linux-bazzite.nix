{
  lib,
  fetchFromGitHub,
  fetchurl,
  linuxManualConfig,
  runCommand,
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

  # Patch the config to disable Rust — nixpkgs rustc doesn't support the
  # no-jump-tables option used in the Fedora config
  configfile = runCommand "bazzite-kernel-config" {} ''
    sed 's/CONFIG_RUST=y/CONFIG_RUST=n/g' \
      ${bazzite}/kernel-x86_64-fedora.config > $out
  '';

  # Strip the bazzite suffix to get the vanilla kernel version e.g. 6.17.7
  kernelVersion = builtins.head (lib.strings.splitString "-" pins.version);

  kernel = linuxManualConfig {
    inherit src lib configfile;
    version = pins.version;
    modDirVersion = kernelVersion;
    allowImportFromDerivation = true;
  };
in

kernel.overrideAttrs (old: {
  patches = [];

  postPatch = ''
    cp ${bazzite}/Makefile.rhelver .

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