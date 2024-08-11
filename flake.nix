{
  inputs = rec {
    nixpkgs.url = "github:NixOS/nixpkgs/24.11-pre";
    zig-overlay = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zls-overlay = {
      url = "github:zigtools/zls/0.13.0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.zig-overlay.follows = "zig-overlay";
    };
  };

  outputs =
    inputs@{ self, nixpkgs, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      zig = inputs.zig-overlay.packages.x86_64-linux.default;
      zls = inputs.zls-overlay.packages.x86_64-linux.zls.overrideAttrs (prev: {
        nativeBuildInputs = [ zig ];
      });

      ruby = pkgs.ruby_3_3.withPackages (rpkgs: with rpkgs; [ruby-lsp]);
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = with pkgs; [
          zls
          zig

          ruby
        ];
      };
    };
}
