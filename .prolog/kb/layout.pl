% Repository layout and design decisions.
:- set_prolog_flag(double_quotes, string).

file_role("flake.nix", "image entrypoint; arch-expert input (github, non-flake) + optional secrets/root-password-hash hook").
file_role("saver.nix", "NixOS module on top of installation-cd-minimal: agents, sshd, saver-init, profile.d wiring").
file_role("agents.md", "AGENTS.md shipped to /etc/saver/AGENTS.md and symlinked to /root/AGENTS.md on the live system").
file_role("build.sh", "nix build .#iso and report ISO path/size/sha").
file_role("install-usb.sh", "USB writer: persistent GPT layout (FAT32 SAVER + ext4 SAVER_DATA) or --dd raw mode").

design("live root", "NixOS installation-cd-minimal base: tmpfs runtime, squashfs store, zstd compression; nothing persists except /data").
design("agent persistence", "saver-init mounts SAVER_DATA at /data, symlinks /data/config/opencode into ~/.config and points ARCH_EXPERT_KB at /data/arch-expert/kb").
design("ssh access", "sshd enabled; keys-only via /data/ssh/authorized_keys unless secrets/root-password-hash was present at build time (then password auth).").
design("boot persistence mode", "p1 FAT32 label SAVER carries the extracted ISO (rsync -rL, symlinks dereferenced); NixOS stage1 scans for the store itself, so no label-dependent cmdline is needed. UEFI only; --dd covers BIOS.").
