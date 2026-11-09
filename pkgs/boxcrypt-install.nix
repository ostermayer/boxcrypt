# The installer program, bound to the system image it installs.
{
  runCommand,
  writeShellApplication,
  coreutils,
  cryptsetup,
  diffutils,
  gptfdisk,
  jq,
  systemd,
  util-linux,
  zfs,
  image,
  imageFile,
}:
let
  imagePath = "${image}/${imageFile}";
  layoutPath = "${image}/repart-output.json";
  manifest = runCommand "boxcrypt-image.sha256" { } ''
    sha256sum ${imagePath} ${layoutPath} > $out
  '';
in
writeShellApplication {
  name = "boxcrypt-install";
  runtimeInputs = [
    coreutils
    cryptsetup
    diffutils
    gptfdisk
    jq
    systemd
    util-linux
    zfs
  ];
  runtimeEnv = {
    BOXCRYPT_IMAGE = imagePath;
    BOXCRYPT_LAYOUT = layoutPath;
    BOXCRYPT_MANIFEST = "${manifest}";
  };
  text = builtins.concatStringsSep "\n" (
    map builtins.readFile [
      ../src/installer/checks.sh
      ../src/installer/drives.sh
      ../src/installer/install.sh
    ]
  );
}
