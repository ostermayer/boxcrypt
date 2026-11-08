# Proves the box answers on the LAN and cannot reach or be reached from outside.
{ self }:
let
  inherit (import ./lib.nix) webServer;
in
{
  name = "cryptbox-network";

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
            dhcp-option = "option:router,192.168.1.1";
          };
        };
      };

    box =
      { lib, pkgs, ... }:
      {
        imports = [ self.nixosModules.default ];
        virtualisation.vlans = [ 1 ];
        networking.interfaces.eth1.ipv4.addresses = lib.mkForce [ ];
        environment.systemPackages = [ pkgs.curl ];
        # Stand-ins for real services: one allowed port, one that must stay closed.
        systemd.services.allowed = webServer pkgs 443;
        systemd.services.closed = webServer pkgs 8080;
      };

    client =
      { lib, pkgs, ... }:
      {
        virtualisation.vlans = [ 1 ];
        networking.firewall.enable = false;
        networking.interfaces.eth1.ipv4.addresses = lib.mkForce [
          {
            address = "192.168.1.50";
            prefixLength = 24;
          }
        ];
        environment.systemPackages = [ pkgs.curl ];
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
      };
  };

  testScript = ''
    TIMEOUT = "--max-time 3"

    start_all()
    router.wait_for_unit("dnsmasq.service")
    outside.wait_for_open_port(80)
    client.wait_for_open_port(80)
    box.wait_for_unit("nftables.service")
    box.wait_for_unit("allowed.service")
    box.wait_for_unit("closed.service")
    box.wait_until_succeeds("ip -4 -o addr show eth1 | grep -q 'inet 192.168.1.1[0-2]'")
    address = box.succeed("ip -4 -o addr show eth1 | awk '{print $4}' | cut -d/ -f1").strip()

    with subtest("takes an address from DHCP but no way out"):
        box.fail("ip route show default | grep -q .")
        box.succeed('test -z "$(ip -6 addr show scope global)"')

    with subtest("answers on the allowed port from the LAN"):
        client.wait_until_succeeds(f"curl -sf {TIMEOUT} http://{address}:443/")

    with subtest("every other port stays closed"):
        client.fail(f"curl -sf {TIMEOUT} http://{address}:8080/")

    with subtest("the outside is reachable from the LAN, so failures below mean something"):
        client.succeed("ip route add default via 192.168.1.1 dev eth1")
        client.succeed(f"curl -sf {TIMEOUT} http://203.0.113.50/")

    with subtest("cannot reach the outside even when handed a route"):
        box.succeed("ip route add default via 192.168.1.1 dev eth1")
        box.fail(f"curl -sf {TIMEOUT} http://203.0.113.50/")

    with subtest("cannot start a connection to the LAN either"):
        box.fail(f"curl -sf {TIMEOUT} http://192.168.1.50/")

    with subtest("refuses public addresses even with a route back"):
        outside.fail(f"curl -sf {TIMEOUT} http://{address}:443/")

    with subtest("the firewall is what blocked those"):
        box.succeed("nft flush ruleset")
        outside.succeed(f"curl -sf {TIMEOUT} http://{address}:443/")
        box.succeed(f"curl -sf {TIMEOUT} http://203.0.113.50/")
        box.succeed(f"curl -sf {TIMEOUT} http://192.168.1.50/")
  '';
}
