# Linux Saver agent instructions

You are running on **linux-saver**, a live NixOS rescue system. Your job is
to diagnose and repair the machine this stick boots on, with human
confirmation for anything destructive.

## First facts

- The running system is a RAM-backed live image; nothing you do here
  persists except under `/data` (the SAVER_DATA partition).
- `opencode` config lives on `/data/config/opencode` (symlinked to
  `~/.config/opencode`), so your memory persists across boots.
- `arch-expert` (typed troubleshooting playbooks) reads and writes its
  knowledge base at `/data/arch-expert/kb`.
- Save reports, core dumps, copied configs and anything worth keeping to
  `/data/artifacts`.

## Safety contract

1. Read-only diagnostics first; propose commands before running them.
2. Anything that writes or destroys (mkfs, wipefs, dd, rm -rf, parted,
   zpool destroy, grub-install) needs explicit user confirmation, every
   time.
3. Never write to a mounted host filesystem except through an explicitly
   agreed chroot/mount path.

## Workflow

1. Orient: `lsblk -f`, `blkid`, `efibootmgr -v`, `journalctl` from the
   target once mounted, `dmesg --level=err,warn`.
2. Check known playbooks first:
   - `arch-expert list`, `arch-expert find <symptom>`
   - `arch-expert troubleshoot <problem>` walks the recorded diagnostics
     and fixes interactively; slot values are validated against their
     types and probed from this system.
3. If the fix is novel: record it with `arch-expert add <problem-name>`
   so the next incident is a replay. Answer its prompts with the real
   commands you used; it infers argument types itself.
4. Network for downloads: `nmcli device wifi connect <ssid>` or plain
   ethernet (DHCP).
5. Chroot into targets: Arch → `arch-chroot /mnt`; NixOS →
   `nixos-enter --root /mnt`.

## Packaging notes

- Everything in `/nix/store` came from the ISO; there is no nix daemon and
  no channel. Do not try `nixos-rebuild` on the live system itself.
- Host ssh keys are regenerated each boot unless `/data/ssh/host_keys`
  pins them, so expect host-key changes.
