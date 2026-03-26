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

  # Limit parallelism to reduce memory pressure and get cleaner error output
  enableParallelBuilding = false;
  makeFlags = (old.makeFlags or []) ++ [ "V=1" ];

  postPatch = ''
    cp ${bazzite}/Makefile.rhelver .

    # Pre-create all drivers/custom subdirectories so patch can populate them
    # patch-3-akmods adds new drivers but needs directories to exist first
    for dir in \
      drivers/custom/evdi/module \
      drivers/custom/v4l2loopback \
      drivers/custom/openrazer \
      drivers/custom/facecam \
      drivers/custom/nct6687d \
      drivers/custom/gcadapter_oc \
      drivers/custom/gpd-fan \
      drivers/custom/ryzen_smu \
      drivers/custom/zenergy \
      drivers/custom/xonedo \
      drivers/custom/ayn_platform; do
      mkdir -p "$dir"
      touch "$dir/Kconfig"
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
    description = "Bazzite kernel - gaming and handheld optimized (NixOS)";
    branch = "bazzite-${lib.versions.major pins.version}";
  };
})