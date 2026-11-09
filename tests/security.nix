# Proves the hardening in modules/security.nix is in effect on a running system.
{ self }:
{
  name = "boxcrypt-security";

  nodes.box =
    { lib, ... }:
    {
      imports = [ self.nixosModules.default ];

      # The test framework gives root an empty password. Remove it to test what ships.
      users.users.root.hashedPasswordFile = lib.mkForce null;
    };

  testScript = ''
    SYSCTLS = {
        "kernel.kptr_restrict": "2",
        "kernel.dmesg_restrict": "1",
        "kernel.yama.ptrace_scope": "2",
        "kernel.unprivileged_bpf_disabled": "1",
        "kernel.kexec_load_disabled": "1",
        "kernel.sysrq": "0",
        "fs.suid_dumpable": "0",
        "kernel.io_uring_disabled": "2",
        "user.max_user_namespaces": "0",
        "net.ipv4.conf.all.accept_redirects": "0",
        "net.ipv4.conf.default.accept_redirects": "0",
        "net.ipv4.conf.all.accept_source_route": "0",
        "net.ipv4.conf.default.accept_source_route": "0",
        "net.ipv4.conf.all.rp_filter": "1",
        "net.ipv4.tcp_syncookies": "1",
        "net.ipv4.conf.all.send_redirects": "0",
        "net.ipv4.conf.default.send_redirects": "0",
        "net.ipv4.conf.default.rp_filter": "1",
        "kernel.perf_event_paranoid": "3",
        "net.core.bpf_jit_harden": "2",
        "fs.protected_fifos": "2",
        "fs.protected_regular": "2",
    }

    KERNEL_PARAMETERS = [
        "init_on_alloc=1",
        "init_on_free=1",
        "slab_nomerge",
        "page_alloc.shuffle=1",
        "randomize_kstack_offset=on",
        "vsyscall=none",
        "debugfs=off",
        "intel_iommu=on",
        "iommu.strict=1",
        "iommu.passthrough=0",
    ]

    box.wait_for_unit("multi-user.target")

    with subtest("kernel settings are applied"):
        for name, expected in SYSCTLS.items():
            actual = box.succeed(f"sysctl -n {name}").strip()
            assert actual == expected, f"{name} is {actual}, expected {expected}"

    with subtest("kernel hardening parameters are applied"):
        cmdline = box.succeed("cat /proc/cmdline").split()
        for parameter in KERNEL_PARAMETERS:
            assert parameter in cmdline, f"{parameter} is missing from the kernel command line"

    with subtest("key material has nowhere to go on disk"):
        box.succeed('test -z "$(swapon --show)"')
        box.succeed("grep -q '/bin/false$' /proc/sys/kernel/core_pattern")

    with subtest("there are no extra ways in"):
        box.fail("systemctl cat sshd.service")
        box.fail("systemctl is-active getty@tty1.service")
        box.fail("systemctl is-active autovt@tty2.service")
        box.fail("command -v sudo")
        box.fail("command -v nix")
        box.succeed("grep -q '^root:!' /etc/shadow")

    with subtest("the modules being blocked really exist"):
        box.succeed("modinfo bluetooth >/dev/null")
        box.succeed("modinfo cfg80211 >/dev/null")

    with subtest("every Wi-Fi driver in the kernel is gated or blocked"):
        # Helpers with no radio of their own. The drivers that use them need cfg80211.
        helpers = {"brcmutil", "ath9k_pci_owl_loader", "wlcore_spi", "wlcore_sdio"}
        unguarded = set(box.succeed(
            "for f in $(find -L /run/booted-system/kernel-modules/lib/modules "
            "\\( -path '*/drivers/net/wireless/*' -o -path '*/drivers/staging/rtl*' \\) -name '*.ko*'); do "
            "m=$(basename $f | sed 's/[.]ko.*//'); "
            "modprobe -n --show-depends $m 2>/dev/null "
            "| grep -qE 'cfg80211|wifi-gate|/bin/false' || echo $m; done"
        ).split()) - helpers
        assert not unguarded, f"Wi-Fi drivers outside the gate: {unguarded}"

    with subtest("radios stay off by default"):
        box.fail("modprobe bluetooth")
        box.fail("modprobe cfg80211")
  '';
}
