{
  description = "linux-saver: NixOS rescue image with opencode + arch-expert";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    arch-expert = {
      # The published expert. For local development:
      #   nix build --override-input arch-expert path:../arch-expert
      url = "github:lost-rob0t/arch-expert";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, arch-expert }:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
      pkgs = nixpkgs.legacyPackages.${system};

      # Optional: commit nothing, but if secrets/root-password-hash exists at
      # build time (output of `mkpasswd -m sha-512`), root gets that password
      # and sshd allows password login.  Without it the image is keys-only.
      rootHashFile = ./secrets/root-password-hash;
      rootHash = if builtins.pathExists rootHashFile
        then lib.strings.removeSuffix "\n" (builtins.readFile rootHashFile)
        else null;

      archExpert = pkgs.callPackage "${arch-expert}/package.nix" {
        src = arch-expert;
      };
    in
    {
      nixosConfigurations.linux-saver = lib.nixosSystem {
        inherit system;
        modules = [
          (import ./saver.nix {
            inherit archExpert rootHash;
            nixpkgsPath = "${nixpkgs}";
          })
        ];
      };

      packages.${system} = rec {
        iso = self.nixosConfigurations.linux-saver.config.system.build.isoImage;
        default = iso;
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [ rsync parted dosfstools e2fsprogs util-linux ];
      };
    };
}
