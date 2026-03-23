{
  lib,
  fetchFromGitHub,
  linuxManualConfig,
  buildPackages,
  perl,
  bc,
  bison,
  flex,
  openssl,
  elfutils,
  stdenv,
}:

let
  pins = builtins.fromJSON (builtins.readFile ../pins.json);

  src = fetchFromGitHub {
    owner = "bazzite-org";
    repo = "kernel-bazzite";
    rev = pins.rev;
    hash = pins.srcHash;
  };

  configfile = stdenv.mkDerivation {
    name = "linux-bazzite-defconfig-${pins.version}";
    inherit src;
    nativeBuildInputs = [ perl bc bison flex openssl elfutils ];
    buildPhase = ''
      make ARCH=x86_64 defconfig
    '';
    installPhase = ''
      cp .config $out
    '';
  };
in

linuxManualConfig {
  inherit src lib configfile;
  version = pins.version;
  modDirVersion = pins.version;
  allowImportFromDerivation = true;

  extraMeta = {
    description = "Bazzite kernel - gaming and handheld optimized";
    branch = "bazzite-${lib.versions.major pins.version}";
  };
}