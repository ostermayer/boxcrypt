# Reachable on the LAN, unable to reach anything else. See doc/modules/network.md.
{ config, lib, ... }:
let
  cfg = config.cryptbox.network;
  dhcpServerPort = 67;
  dhcpClientPort = 68;
in
{
  options.cryptbox.network.tcpPorts = lib.mkOption {
    type = lib.types.nonEmptyListOf lib.types.port;
    default = [ 443 ];
    description = "TCP ports accepted from private address ranges.";
  };

  config = {
    networking = {
      hostName = "cryptbox";
      enableIPv6 = false;
      useNetworkd = true;
      useDHCP = false;
      nameservers = [ ];

      firewall.enable = false;
      nftables = {
        enable = true;
        ruleset = ''
          table inet cryptbox {
            set lan {
              type ipv4_addr
              flags interval
              elements = { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16 }
            }

            chain input {
              type filter hook input priority filter; policy drop;
              iif lo accept
              ct state established,related accept
              ct state invalid drop
              udp sport ${toString dhcpServerPort} udp dport ${toString dhcpClientPort} accept
              ip saddr @lan tcp dport { ${lib.concatMapStringsSep ", " toString cfg.tcpPorts} } accept
            }

            chain forward {
              type filter hook forward priority filter; policy drop;
            }

            chain output {
              type filter hook output priority filter; policy drop;
              oif lo accept
              ct state established,related accept
              udp sport ${toString dhcpClientPort} udp dport ${toString dhcpServerPort} accept
            }
          }
        '';
      };
    };

    systemd.network = {
      wait-online.enable = false;
      networks."10-lan" = {
        matchConfig.Type = "ether wlan";
        networkConfig = {
          DHCP = "ipv4";
          LinkLocalAddressing = "no";
          IPv6AcceptRA = false;
        };
        # Take an address from DHCP and nothing else, least of all a way out.
        dhcpV4Config = {
          UseGateway = false;
          UseRoutes = false;
          UseDNS = false;
          UseNTP = false;
          UseHostname = false;
          SendHostname = false;
        };
      };
    };

    services.resolved.enable = false;
    services.timesyncd.enable = false;
  };
}
