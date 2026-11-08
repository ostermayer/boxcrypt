# Proves Wi-Fi stays off by default, and keeps the same limits once the owner chooses it.
{ self }:
let
  inherit (import ./lib.nix) webServer;
in
{
  name = "cryptbox-wifi";

  nodes.box =
    { pkgs, ... }:
    {
      imports = [ self.nixosModules.default ];

      environment.systemPackages = with pkgs; [
        curl
        dnsmasq
        hostapd
        iw
      ];

      environment.etc."hostapd-test.conf".text = ''
        interface=wlan0
        driver=nl80211
        ssid=cryptbox-test
        hw_mode=g
        channel=1
        wpa=2
        wpa_key_mgmt=WPA-PSK
        rsn_pairwise=CCMP
        wpa_passphrase=test-passphrase
      '';

      # Stand-ins for real services: one allowed port, one that must stay closed.
      systemd.services.allowed = webServer pkgs 443;
      systemd.services.closed = webServer pkgs 8080;
    };

  testScript = ''
    MARKER = "/persist/network/wifi-enabled"
    AP = "ip netns exec ap"
    TIMEOUT = "--max-time 5"
    DNSMASQ_OPTIONS = " ".join([
        "--port=0",
        "--interface=wlan0",
        "--bind-interfaces",
        "--no-resolv",
        "--no-hosts",
        "--user=root",
        "--pid-file=/run/dnsmasq-ap.pid",
        "--dhcp-leasefile=/run/dnsmasq-ap.leases",
        "--dhcp-range=192.168.50.100,192.168.50.120,1h",
        "--dhcp-option=option:router,192.168.50.1",
    ])

    box.wait_for_unit("multi-user.target")
    box.wait_for_unit("nftables.service")
    box.wait_for_open_port(443)
    box.wait_for_open_port(8080)

    with subtest("no Wi-Fi driver can load until the owner chooses Wi-Fi"):
        box.fail("modprobe cfg80211")
        box.fail("modprobe mac80211_hwsim")
        box.fail("lsmod | grep -q '^cfg80211'")
        box.fail("systemctl is-active iwd.service")

    with subtest("choosing Wi-Fi allows the drivers"):
        box.succeed(f"touch {MARKER}")
        box.succeed("modprobe mac80211_hwsim radios=2")

    with subtest("joins a network and takes an address"):
        # The access point has its own network namespace, so traffic really crosses
        # the simulated radio and the box's firewall.
        box.succeed("ip netns add ap")
        box.succeed("iw phy phy0 set netns name ap")
        box.succeed(f"{AP} ip link set lo up")
        box.succeed(f"{AP} ip addr add 192.168.50.1/24 dev wlan0")
        box.succeed(f"{AP} ip link set wlan0 up")
        box.succeed(f"{AP} hostapd -B /etc/hostapd-test.conf")
        box.succeed(f"{AP} dnsmasq {DNSMASQ_OPTIONS}")
        box.succeed("printf '[Security]\\nPassphrase=test-passphrase\\n' > /persist/network/iwd/cryptbox-test.psk")
        box.succeed("systemctl start iwd.service")
        box.wait_until_succeeds("ip -4 -o addr show | grep -q 'inet 192.168.50.1[0-2]'", timeout=60)
        address = box.succeed("ip -4 -o addr show | awk '/192.168.50/ {print $4}' | cut -d/ -f1").strip()

    with subtest("gets no way out over Wi-Fi either"):
        box.fail("ip route show default | grep -q .")

    with subtest("the same firewall applies over Wi-Fi"):
        box.succeed(f"{AP} curl -sf {TIMEOUT} http://{address}:443/")
        box.fail(f"{AP} curl -sf {TIMEOUT} http://{address}:8080/")

    with subtest("the firewall is what blocked that"):
        box.succeed("nft flush ruleset")
        box.succeed(f"{AP} curl -sf {TIMEOUT} http://{address}:8080/")
  '';
}
