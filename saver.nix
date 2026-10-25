# linux-saver NixOS module: live rescue image with agents on board.
{ archExpert, rootHash, nixpkgsPath }:
{ config, pkgs, lib, ... }:

{
  imports = [
    (nixpkgsPath + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix")
  ];

  # ------------------------------------------------------------------ image

  image.baseName = lib.mkForce "linux-saver";
  isoImage.volumeID = lib.mkForce "SAVER";
  isoImage.appendToMenuLabel = lib.mkForce " Linux Saver";
  # zstd boots much faster than the default xz on large closures.
  isoImage.squashfsCompression = lib.mkForce "zstd -Xcompression-level 15";

  # ------------------------------------------------------------------ agents

  environment.systemPackages = [
    archExpert
    pkgs.opencode
    pkgs.swi-prolog
  ] ++ (with pkgs; [
    git
    neovim
    tmux
    jq
    efibootmgr
    gptfdisk
    dosfstools
    ntfs3g
    btrfs-progs
    smartmontools
    testdisk
    nixos-install-tools # nixos-enter for chrooting into NixOS targets
  ]);

  environment.variables.ARCH_EXPERT_HOME = "${archExpert}/share/arch-expert";

  # Recovery playbook for opencode agents (symlinked to /root/AGENTS.md).
  environment.etc."saver/AGENTS.md".source = ./agents.md;

  # ------------------------------------------------------------------ access

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = if rootHash != null then "yes" else "prohibit-password";
      PasswordAuthentication = lib.mkDefault (rootHash != null);
    };
  };

  users.users.root = lib.mkIf (rootHash != null) {
    hashedPassword = rootHash;
  };

  networking.networkmanager.enable = true;

  # ------------------------------------------------------------------ data

  # Mount the persistent SAVER_DATA partition (if present) and wire the
  # agent environment to it: opencode config, arch-expert KB, ssh keys.
  systemd.services.saver-init = {
    description = "Mount SAVER_DATA and wire agent environment";
    after = [ "local-fs.target" ];
    before = [ "sshd.service" ];
    wantedBy = [ "multi-user.target" "sshd.service" ];
    unitConfig.ConditionPathExists = "/dev/disk/by-label/SAVER_DATA";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = with pkgs; [ util-linux coreutils ];
    script = ''
      set -u
      mkdir -p /data
      if ! mountpoint -q /data; then
        mount /dev/disk/by-label/SAVER_DATA /data || {
          echo "saver-init: failed to mount SAVER_DATA" >&2
          exit 1
        }
      fi

      mkdir -p /data/config/opencode /data/arch-expert/kb /data/arch-expert/state \
               /data/artifacts /root/.config /root/.ssh

      # persistent opencode config (memory, agents, MCP wiring)
      ln -sfn /data/config/opencode /root/.config/opencode

      # agent instructions
      ln -sfn /etc/saver/AGENTS.md /root/AGENTS.md

      # ssh access: keys prepared on the data partition
      if [ -f /data/ssh/authorized_keys ]; then
        cp /data/ssh/authorized_keys /root/.ssh/authorized_keys
        chmod 700 /root/.ssh
        chmod 600 /root/.ssh/authorized_keys
      fi

      # optionally pinned host keys (ssh/seed-host-keys.sh on the data partition)
      if [ -d /data/ssh/host_keys ]; then
        cp /data/ssh/host_keys/* /etc/ssh/
        chmod 600 /etc/ssh/ssh_host_*_key
        chmod 644 /etc/ssh/ssh_host_*_key.pub
      fi

      touch /run/saver-data-ready
      echo "saver-init: persistent data online at /data"
    '';
  };

  environment.etc."profile.d/saver.sh".text = ''
    # wire persistent agent data when present
    if [ -d /data/arch-expert/kb ]; then
      export ARCH_EXPERT_KB=/data/arch-expert/kb
      export ARCH_EXPERT_STATE=/data/arch-expert/state
    fi
    export SAVER_ARTIFACTS=/data/artifacts
    alias saver-agent='cd /root && opencode'
  '';
}
