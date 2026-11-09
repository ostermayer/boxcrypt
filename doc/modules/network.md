# Network

> **Status: firewall and routing are built and VM-tested.** Address pinning and app
> ports are still to come. See ADR-013.

## Purpose

Make the box reachable on the LAN and unable to reach anything else.

## Behaviour

| Direction | Rule |
|---|---|
| Inbound | TCP 443 and multicast DNS from private address ranges, rate-limited DHCP replies from them, and IGMP on the local link |
| Outbound | Replies to established connections, DHCP to private or broadcast addresses, multicast DNS and direct replies to private addresses, and IGMP so that switches keep forwarding multicast |
| Name | `boxcrypt.local`, until the owner changes it |
| Forwarding | None |
| Routing | DHCP gateway ignored, so no default route |
| IPv6 | Disabled |
| Wi-Fi | Off unless the owner chooses it |
| Bluetooth | Always off |

If the firewall fails to load, networking does not start, so the box fails closed. USB
network adapters are never configured, because one could be an attacker's.

Enabling an add-on app adds its port to the inbound rule, and disabling it removes the
port.

The box takes its address by DHCP. Owners reach it by name, so the address can change
without any effect. A restored box keeps its name and certificate.

## Wi-Fi

Wired is the default and the recommendation. An owner without a cable can choose Wi-Fi
during installation, when a monitor and keyboard are connected.

- Until then, a gate on `cfg80211` stops every Wi-Fi driver from loading, and `iwd` does
  not start.
- Choosing Wi-Fi creates `/persist/network/wifi-enabled`. Turning it on or off takes
  effect after a restart, because kernel module loading is locked once the box has booted.
- The box joins as a client only. The same firewall and no-gateway rules apply.
- The network password is stored unencrypted in `/persist/network/iwd`, because the box
  must join before it can show the unlock page. A stolen box reveals it.

## Module options

| Option | Default | Purpose |
|---|---|---|
| `boxcrypt.network.tcpPorts` | `[ 443 ]` | Ports accepted from private ranges |

## Edge cases

- **Two devices with the same name:** the second takes a different name and shows it in
  the web UI.
- **A device that cannot resolve `.local` names:** the owner uses the address from the
  router's device list.
- **No DHCP on the network:** the installer asks for an address.
- **Several Ethernet ports:** each with a link takes an address.
- **Moved to a different network:** nothing changes, because owners use the name.

## Owner guidance

Never forward a port from your router to the box. Internet traffic forwarded that way can
arrive with a private source address and pass the firewall.

Block the box's address from the internet at the router as well. This is part of the
design, not an extra. A live kernel compromise could change the box's own firewall until
the next reboot, but nothing on the box can change a router rule. See
[integrity](integrity.md).
