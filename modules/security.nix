# Hardening for a machine with one job. See doc/modules/system.md.
{ lib, pkgs, ... }:
let
  refuse = "${pkgs.coreutils}/bin/false";

  disabledKernelModules = [
    # Bluetooth has no use here. Wi-Fi has its own gate in wifi.nix.
    "bluetooth"
    "btusb"

    # DMA-capable buses with no use here.
    "firewire_core"
    "thunderbolt"

    # Network protocols with a history of kernel bugs and no use here.
    "dccp"
    "sctp"
    "rds"
    "tipc"
  ];
in
{
  boot.kernel.sysctl = {
    # Deny attackers a map of the kernel.
    "kernel.kptr_restrict" = 2;
    "kernel.dmesg_restrict" = 1;
    "kernel.perf_event_paranoid" = 3;

    # Keep one compromised process away from another's memory, where keys live.
    "kernel.yama.ptrace_scope" = 2;
    "kernel.unprivileged_bpf_disabled" = 1;
    "net.core.bpf_jit_harden" = 2;

    # Nothing on this machine replaces the running kernel or needs magic keys.
    "kernel.kexec_load_disabled" = 1;
    "kernel.sysrq" = 0;

    # A crash must never write key material to disk.
    "kernel.core_pattern" = lib.mkForce "|${refuse}";
    "fs.suid_dumpable" = 0;

    "fs.protected_fifos" = 2;
    "fs.protected_regular" = 2;

    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.tcp_syncookies" = 1;
  };

  boot.kernelParams = [
    # Clear memory on free, so released keys do not linger in RAM.
    "init_on_alloc=1"
    "init_on_free=1"
    "slab_nomerge"
    "page_alloc.shuffle=1"
    "randomize_kstack_offset=on"
    "vsyscall=none"
    "debugfs=off"
  ];

  # A blacklist only stops automatic loading. `install` stops explicit loading too.
  boot.extraModprobeConfig = lib.concatMapStringsSep "\n" (
    module: "install ${module} ${refuse}"
  ) disabledKernelModules;

  security.protectKernelImage = true;

  # Keys live in RAM, and nothing may copy them to disk.
  swapDevices = lib.mkForce [ ];
  systemd.coredump.enable = false;
  systemd.settings.Manager.DefaultLimitCORE = 0;

  # The web UI and TUI are the only ways in.
  services.openssh.enable = false;
  security.sudo.enable = false;
  users.mutableUsers = false;
  users.allowNoPasswordLogin = true;
  users.users.root.hashedPassword = "!";

  # Updates arrive as signed system images, so nothing needs Nix at runtime.
  nix.enable = false;

  environment.defaultPackages = lib.mkForce [ ];
  documentation.enable = false;
  programs.command-not-found.enable = false;
}
