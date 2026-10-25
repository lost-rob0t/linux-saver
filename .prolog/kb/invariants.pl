% Verified invariants and pitfalls of building this image.
:- set_prolog_flag(double_quotes, string).

invariant(option_priority, "installation-cd-minimal sets image.baseName/volumeID/compression itself; linux-saver overrides must use lib.mkForce (plain assignments cause 'conflicting definition values' on image.baseName).").
invariant(pure_eval_paths, "path:../arch-expert as a flake input does not get a narHash in flake.lock, so pure eval fails ('too short to be a valid store path' / 'absolute path forbidden'). Consume the published github input instead and use --override-input for local dev.").
invariant(fat_extraction, "FAT32 cannot hold symlinks; the ISO tree must be copied with rsync -rL. Kernel/initrd/store files boot fine because NixOS stage1 searches devices for the store path.").
invariant(saver_init_gating, "saver-init uses ConditionPathExists on /dev/disk/by-label/SAVER_DATA and before=sshd.service so a stick without a data partition still boots sshd unauthenticated-by-keys.").
invariant(opencode_source, "opencode ships in nixpkgs unstable as pkgs.opencode (verified 2.1.1 on 2026-10-25).").
