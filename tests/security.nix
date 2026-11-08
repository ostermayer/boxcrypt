# Proves the hardening in modules/security.nix is in effect on a running system.
{ self }:
{
  name = "cryptbox-security";

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
    }

    box.wait_for_unit("multi-user.target")

    with subtest("kernel settings are applied"):
        for name, expected in SYSCTLS.items():
            actual = box.succeed(f"sysctl -n {name}").strip()
            assert actual == expected, f"{name} is {actual}, expected {expected}"

    with subtest("memory is cleared on free"):
        box.succeed("grep -q init_on_free=1 /proc/cmdline")

    with subtest("key material has nowhere to go on disk"):
        box.succeed('test -z "$(swapon --show)"')
        box.succeed("grep -q '/bin/false$' /proc/sys/kernel/core_pattern")

    with subtest("there are no extra ways in"):
        box.fail("systemctl cat sshd.service")
        box.fail("command -v sudo")
        box.fail("command -v nix")
        box.succeed("grep -q '^root:!' /etc/shadow")

    with subtest("radios stay off by default"):
        box.fail("modprobe bluetooth")
        box.fail("modprobe cfg80211")
  '';
}
