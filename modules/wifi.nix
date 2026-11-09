# Wi-Fi stays off unless the owner chooses it. See ADR-016.
{ pkgs, ... }:
let
  networkState = "/persist/network";
  enabledMarker = "${networkState}/wifi-enabled";
  iwdState = "${networkState}/iwd";

  # Every modern Wi-Fi driver depends on cfg80211, so this one gate covers them all.
  driverGate = pkgs.writeShellScript "boxcrypt-wifi-gate" ''
    [ -e ${enabledMarker} ] || exit 1
    exec ${pkgs.kmod}/bin/modprobe --ignore-install cfg80211 "$@"
  '';
in
{
  boot.extraModprobeConfig = "install cfg80211 ${driverGate} $CMDLINE_OPTS";

  hardware.wirelessRegulatoryDatabase = true;

  networking.wireless.iwd.enable = true;

  systemd.tmpfiles.rules = [
    "d ${networkState} 0700 root root -"
    "d ${iwdState} 0700 root root -"
  ];

  systemd.services.iwd = {
    unitConfig.ConditionPathExists = enabledMarker;

    # The radio must never come up without the firewall.
    requires = [ "nftables.service" ];
    after = [ "nftables.service" ];

    # The box must join the network before it can show the unlock page, so network
    # passwords live here rather than in the encrypted store.
    serviceConfig.BindPaths = [ "${iwdState}:/var/lib/iwd" ];
  };
}
