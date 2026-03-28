{
  lib,
  fetchFromGitHub,
  fetchurl,
  linuxManualConfig,
  runCommand,
}:

let
  # ============================================================
  # SECTION: PIN LOADING
  # ============================================================
  pins = builtins.fromJSON (builtins.readFile ../pins.json);

  # ============================================================
  # SECTION: BAZZITE PACKAGING REPO
  # ============================================================
  bazzite = fetchFromGitHub {
    owner = "bazzite-org";
    repo = "kernel-bazzite";
    rev = pins.rev;
    hash = pins.srcHash;
  };

  # ============================================================
  # SECTION: VANILLA KERNEL SOURCE
  # ============================================================
  src = fetchurl {
    url = "mirror://kernel/linux/kernel/v6.x/linux-${lib.versions.majorMinor pins.version}.${lib.versions.patch pins.version}.tar.xz";
    hash = pins.kernelHash;
  };

  # ============================================================
  # SECTION: KERNEL CONFIG
  # Patch the config to disable Rust — nixpkgs rustc doesn't support the
  # no-jump-tables option used in the Fedora config
  # ============================================================
  configfile = runCommand "bazzite-kernel-config" {} ''
    sed 's/CONFIG_RUST=y/CONFIG_RUST=n/g' \
      ${bazzite}/kernel-x86_64-fedora.config > $out
  '';

  # ============================================================
  # SECTION: VERSION HANDLING
  # Strip the bazzite suffix to get the vanilla kernel version e.g. 6.17.7
  # ============================================================
  kernelVersion = builtins.head (lib.strings.splitString "-" pins.version);

  # ============================================================
  # SECTION: BASE KERNEL DERIVATION
  # ============================================================
  kernel = linuxManualConfig {
    inherit src lib configfile;
    version = pins.version;
    modDirVersion = kernelVersion;
    allowImportFromDerivation = true;
  };
in

# ============================================================
# SECTION: KERNEL OVERRIDES
# ============================================================
kernel.overrideAttrs (old: {

  # ============================================================
  # SECTION: PATCH REMOVAL
  # Clear nixpkgs default patches — bazzite source is not a vanilla tree
  # ============================================================
  patches = [];

  # ============================================================
  # SECTION: POST PATCH
  # ============================================================
  postPatch = ''
    # Copy bazzite packaging files needed by the patched Makefile
    cp ${bazzite}/Makefile.rhelver .

    # Copy the broadcom-wl binary blob required by the broadcom-wl driver
    mkdir -p drivers/custom/broadcom-wl/lib
    cp ${bazzite}/broadcom-wl.blob drivers/custom/broadcom-wl/lib/wlc_hybrid.o_shipped

    # Pre-create ALL directories that patch-3-akmods references under drivers/custom
    # Scans the patch itself so this works automatically for future bazzite versions
    grep -oP 'drivers/custom/[^/\s]+' ${bazzite}/patch-3-akmods.patch \
      | sort -u \
      | while read dir; do
          mkdir -p "$dir"
          touch "$dir/Kconfig"
        done

    # Apply bazzite patches
    for p in \
      ${bazzite}/patch-1-redhat.patch \
      ${bazzite}/patch-2-handheld.patch \
      ${bazzite}/patch-3-akmods.patch \
      ${bazzite}/patch-4-amdgpu-vrr-whitelist.patch; do
      echo "Applying $p"
      patch -p1 --forward --no-backup-if-mismatch < "$p" || true
    done

    # Patch evdi Makefile to not require /etc/os-release (doesn't exist in Nix sandbox)
    if [ -f drivers/custom/evdi/module/Makefile ]; then
      sed -i '/os-release/d' drivers/custom/evdi/module/Makefile
    fi
  '' + (old.postPatch or "");

  # ============================================================
  # SECTION: METADATA
  # ============================================================
  extraMeta = {
    description = "Bazzite kernel - gaming and handheld optimized (NixOS)";
    branch = "bazzite-${lib.versions.major pins.version}";
  };
})