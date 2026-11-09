# Proves the box answers on the LAN and cannot reach or be reached from outside.
{ self }:
let
  inherit (import ./lib.nix) webServer;
in
{
  name = "boxcrypt-network";

  nodes = {
    # Offers a gateway by DHCP and forwards between the LAN and the outside.
    router =
      { lib, ... }:
      {
        virtualisation.vlans = [
          1
          2
        ];
        boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
        networking.firewall.enable = false;
        networking.interfaces.eth1.ipv4.addresses = lib.mkForce [
          {
            address = "192.168.1.1";
            prefixLength = 24;
          }
        ];
        networking.interfaces.eth2.ipv4.addresses = lib.mkForce [
          {
            address = "203.0.113.1";
            prefixLength = 24;
          }
        ];
        services.dnsmasq = {
          enable = true;
          resolveLocalQueries = false;
          settings = {
            port = 0;
            interface = "eth1";
            dhcp-range = "192.168.1.100,192.168.1.120,1h";
            # A gateway offered both ways a DHCP server can offer one.
            dhcp-option = [
              "option:router,192.168.1.1"
              "option:classless-static-route,0.0.0.0/0,192.168.1.1"
            ];
          };
        };
      };

    box =
      { lib, pkgs, ... }:
      {
        imports = [ self.nixosModules.default ];
        virtualisation.vlans = [ 1 ];
        # A USB network adapter with a working DHCP server behind it.
        virtualisation.qemu.options = [
          "-device qemu-xhci"
          "-netdev user,id=usbnet"
          "-device usb-net,netdev=usbnet"
        ];
        networking.interfaces.eth1.ipv4.addresses = lib.mkForce [ ];
        environment.systemPackages = [
          pkgs.curl
          pkgs.socat
        ];
        # Stand-ins for real services: one allowed port, one that must stay closed.
        systemd.services.allowed = webServer pkgs 443;
        systemd.services.closed = webServer pkgs 8080;
        systemd.services.closed-low = webServer pkgs 22;
      };

    # Its firewall cannot load, so it must stay off the network.
    broken =
      { lib, pkgs, ... }:
      {
        imports = [ self.nixosModules.default ];
        virtualisation.vlans = [ 1 ];
        networking.interfaces.eth1.ipv4.addresses = lib.mkForce [ ];
        systemd.services.nftables.serviceConfig.ExecStart = lib.mkForce "${pkgs.coreutils}/bin/false";
      };

    client =
      { lib, pkgs, ... }:
      {
        virtualisation.vlans = [ 1 ];
        networking.firewall.enable = false;
        services.resolved = {
          enable = true;
          settings.Resolve.MulticastDNS = "yes";
        };
        networking.interfaces.eth1.ipv4.addresses = lib.mkForce [
          {
            address = "192.168.1.50";
            prefixLength = 24;
          }
        ];
        environment.systemPackages = [
          pkgs.curl
          pkgs.socat
          pkgs.tcpdump
        ];
        systemd.services.web = webServer pkgs 80;
      };

    outside =
      { lib, pkgs, ... }:
      {
        virtualisation.vlans = [ 2 ];
        networking.firewall.enable = false;
        networking.interfaces.eth1.ipv4.addresses = lib.mkForce [
          {
            address = "203.0.113.50";
            prefixLength = 24;
          }
        ];
        networking.defaultGateway = {
          address = "203.0.113.1";
          interface = "eth1";
        };
        environment.systemPackages = [ pkgs.curl ];
        systemd.services.web = webServer pkgs 80;

        # Catches anything sent from the DHCP client port to the DHCP server port.
        systemd.services.udp-sink = {
          wantedBy = [ "multi-user.target" ];
          serviceConfig.ExecStart = "${pkgs.socat}/bin/socat -u UDP4-RECV:67 OPEN:/tmp/udp-probe,creat,append";
        };
      };
  };

  testScript = ''
    TIMEOUT = "--max-time 3"
    # The DHCP client already holds port 68, so the probe has to share it.
    UDP_PROBE = "echo probe | socat - UDP4-SENDTO:203.0.113.50:67,sourceport=68,reuseaddr"
    PRIVATE_DHCP_PROBE = "echo probe | socat - UDP4-SENDTO:192.168.1.1:67,sourceport=68,reuseaddr"
    # An IGMP general query: type 0x11, maximum response time 10 seconds, checksum, no group.
    IGMP_QUERY = "\\021\\144\\356\\233\\0\\0\\0\\0"
    # A DNS question for boxcrypt.local, type A, class IN.
    MDNS_QUERY = "\\0\\0\\0\\0\\0\\1\\0\\0\\0\\0\\0\\0\\10boxcrypt\\5local\\0\\0\\1\\0\\1"

    start_all()
    router.wait_for_unit("dnsmasq.service")
    outside.wait_for_open_port(80)
    client.wait_for_open_port(80)
    box.wait_for_unit("nftables.service")
    box.wait_for_open_port(443)
    box.wait_for_open_port(8080)
    box.wait_for_open_port(22)
    outside.wait_for_unit("udp-sink.service")
    box.wait_until_succeeds("ip -4 -o addr show eth1 | grep -q 'inet 192.168.1.1[0-2]'")
    address = box.succeed("ip -4 -o addr show eth1 | awk '{print $4}' | cut -d/ -f1").strip()

    with subtest("takes an address from DHCP but no way out"):
        box.fail("ip route show default | grep -q .")
        box.succeed("sysctl -n net.ipv6.conf.all.disable_ipv6 | grep -qx 1")

    with subtest("no network comes up if the firewall fails to load"):
        for dependency in ["Requires", "After"]:
            value = box.succeed(f"systemctl show -p {dependency} systemd-networkd.service")
            assert "nftables.service" in value, f"{dependency}: {value}"
        box.fail("journalctl -b | grep -q 'ordering cycle'")
        broken.wait_for_unit("multi-user.target")
        broken.fail("systemctl is-active nftables.service")
        broken.fail("systemctl is-active systemd-networkd.service")
        broken.fail("ip -4 -o addr show eth1 | grep -q inet")

    with subtest("a USB network adapter is not configured"):
        find_usb = "for n in /sys/class/net/*; do udevadm info -q property $n | grep -q ID_BUS=usb && basename $n; done"
        box.wait_until_succeeds(f"test -n \"$({find_usb})\"")
        usb_interface = box.succeed(find_usb).strip()
        box.succeed("sleep 5")
        box.fail(f"ip -4 addr show {usb_interface} | grep -q inet")

    with subtest("answers to boxcrypt.local on the LAN"):
        client.succeed("resolvectl mdns eth1 yes")
        client.wait_until_succeeds(f"resolvectl query --protocol=mdns boxcrypt.local | grep -q {address}", timeout=60)

    with subtest("answers a query from a random port with a direct reply"):
        here = "192.168.1.50"
        ask = f"UDP4-DATAGRAM:224.0.0.251:5353,bind={here},ip-multicast-if={here}"
        client.wait_until_succeeds(f"printf '{MDNS_QUERY}' | socat -t3 - {ask} | grep -aq boxcrypt", timeout=30)

    with subtest("joins the mDNS group and answers queries, so a switch that filters multicast still forwards it"):
        capture = f"(tcpdump -lnvc1 -i eth1 igmp and src {address} > /tmp/igmp 2>&1 &) ; sleep 2"
        box.succeed("resolvectl mdns eth1 no; sleep 1")
        client.succeed(capture)
        box.succeed("resolvectl mdns eth1 yes")
        client.wait_until_succeeds("grep -q 224.0.0.251 /tmp/igmp", timeout=20)
        # The join repeats for a few seconds. Wait, so the next report answers the query.
        client.succeed("sleep 5", "rm /tmp/igmp", capture)
        client.succeed(f"printf '{IGMP_QUERY}' | socat - IP4-SENDTO:224.0.0.1:2,ip-multicast-if={here}")
        client.wait_until_succeeds("grep -q 224.0.0.251 /tmp/igmp", timeout=20)

    with subtest("renews its DHCP lease through the firewall"):
        lease = "networkctl status --json=short eth1 | grep -o 'LeaseTimestampUSec.:[0-9]*'"
        before = box.succeed(lease).strip()
        box.succeed("networkctl renew eth1")
        box.wait_until_succeeds(f"test \"$({lease})\" != '{before}'", timeout=30)

    with subtest("only the network services can send on the DHCP and mDNS ports"):
        box.fail(PRIVATE_DHCP_PROBE)
        mdns_probe = f"echo probe | socat - UDP4-SENDTO:224.0.0.251:5353,sourceport=5353,reuseaddr,ip-multicast-if={address}"
        box.fail(mdns_probe)
        direct_probe = "echo probe | socat - UDP4-SENDTO:192.168.1.50:5353,sourceport=5353,reuseaddr"
        box.fail(direct_probe)

    with subtest("answers on the allowed port from the LAN"):
        client.wait_until_succeeds(f"curl -sf {TIMEOUT} http://{address}:443/")

    with subtest("other ports stay closed, and the firewall opens only the one"):
        input_rules = box.succeed("nft list chain inet boxcrypt input")
        assert input_rules.count("tcp dport") == 1 and "tcp dport 443 accept" in input_rules, input_rules
        client.fail(f"curl -sf {TIMEOUT} http://{address}:8080/")
        client.fail(f"curl -sf {TIMEOUT} http://{address}:22/")

    with subtest("the outside is reachable from the LAN, so failures below mean something"):
        client.succeed("ip route add default via 192.168.1.1 dev eth1")
        client.succeed(f"curl -sf {TIMEOUT} http://203.0.113.50/")

    with subtest("cannot reach the outside even when handed a route"):
        box.succeed("ip route add default via 192.168.1.1 dev eth1")
        box.fail(f"curl -sf {TIMEOUT} http://203.0.113.50/")

    with subtest("the DHCP ports cannot reach a public address"):
        box.execute(UDP_PROBE)
        outside.succeed("sleep 2")
        outside.fail("test -s /tmp/udp-probe")

    with subtest("cannot start a connection to the LAN either"):
        box.fail(f"curl -sf {TIMEOUT} http://192.168.1.50/")

    with subtest("refuses public addresses even with a route back"):
        outside.fail(f"curl -sf {TIMEOUT} http://{address}:443/")

    with subtest("the firewall is what blocked those"):
        box.succeed("nft flush ruleset")
        outside.succeed(f"curl -sf {TIMEOUT} http://{address}:443/")
        box.succeed(f"curl -sf {TIMEOUT} http://203.0.113.50/")
        box.succeed(f"curl -sf {TIMEOUT} http://192.168.1.50/")
        box.succeed(UDP_PROBE)
        outside.wait_until_succeeds("test -s /tmp/udp-probe", timeout=10)
        box.succeed(PRIVATE_DHCP_PROBE)
        box.succeed(mdns_probe)
        box.succeed(direct_probe)
  '';
}
