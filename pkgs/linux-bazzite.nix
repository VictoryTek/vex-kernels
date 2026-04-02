{
  lib,
  fetchFromGitHub,
  fetchurl,
  linuxManualConfig,
  runCommand,
  # features ? {} absorbs NixOS kernel.nix's `.override { features = ...; }` calls.
  # linuxManualConfig does not auto-expose passthru.features (unlike buildLinux),
  # so without this arg the override fails with "unexpected argument 'features'".
  # The value is intentionally ignored — CONFIG_IA32_EMULATION and CONFIG_EFI_STUB
  # are already enabled in the Fedora gaming config that Bazzite ships.
  features ? {},
  # Absorb randstructSeed and any other args injected by the nixpkgs kernel
  # override chain (kernel.nix, linuxPackagesFor, etc.).
  ...  
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
    sed \
      -e 's/CONFIG_RUST=y/CONFIG_RUST=n/g' \
      -e 's/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION="${localVersion}"/' \
      -e 's/^CONFIG_LOCALVERSION_AUTO=y/CONFIG_LOCALVERSION_AUTO=n/' \
      ${bazzite}/kernel-x86_64-fedora.config > $out
    # Ensure CONFIG_LOCALVERSION is present even if the upstream config omits it
    grep -q '^CONFIG_LOCALVERSION=' $out || echo 'CONFIG_LOCALVERSION="${localVersion}"' >> $out
    grep -q '^CONFIG_LOCALVERSION_AUTO=' $out || echo 'CONFIG_LOCALVERSION_AUTO=n' >> $out
  '';

  # ============================================================
  # SECTION: VERSION HANDLING
  # kernelVersion: vanilla base e.g. "6.17.7"
  # bazziteSuffix: bazzite release tag e.g. "ba28" (from pins.version "6.17.7-ba28")
  # localVersion:  full local suffix matching Bazzite's naming e.g. "-ba28.fc43.x86_64"
  # ============================================================
  kernelVersion = builtins.head (lib.strings.splitString "-" pins.version);
  bazziteSuffix = builtins.elemAt (lib.strings.splitString "-" pins.version) 1;
  localVersion  = "-${bazziteSuffix}.fc43.x86_64";

  # ============================================================
  # SECTION: BASE KERNEL DERIVATION
  # ============================================================
  kernel = linuxManualConfig {
    inherit src lib configfile;
    version = pins.version;
    modDirVersion = "${kernelVersion}${localVersion}";
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
# Expose features at the top level so NixOS assertion checks pass:
#   hardware.graphics.enable32Bit assertion requires features.ia32Emulation = true
#   systemd-boot assertion requires features.efiBootStub = true
# Bazzite ships the Fedora gaming config: CONFIG_IA32_EMULATION=y, CONFIG_EFI_STUB=y.
# Using `//` adds Nix-level metadata only — the derivation and its store path are unchanged.
// { features = { ia32Emulation = true; efiBootStub = true; }; }