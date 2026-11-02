# SPDX-License-Identifier: MIT
{
  description = "Run the RISC Algorithm Language (RISCAL) with Nix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      riscal = pkgs.callPackage ./pkgs/riscal/package.nix { };
      app = {
        type = "app";
        program = "${riscal}/bin/riscal";
        meta.description = "RISC Algorithm Language graphical application";
      };
    in
    {
      packages.${system} = {
        inherit riscal;
        default = riscal;
      };

      apps.${system} = {
        default = app;
        riscal = app;
      };

      overlays.default = final: _prev: {
        riscal = final.callPackage ./pkgs/riscal/package.nix { };
      };

      checks.${system} = {
        package = riscal;
        smoke = import ./tests/smoke.nix { inherit pkgs riscal; };
        flake-interface =
          assert self.packages.${system}.default.outPath == riscal.outPath;
          assert self.apps.${system}.default.program == "${riscal}/bin/riscal";
          assert self.apps.${system}.riscal == self.apps.${system}.default;
          assert (pkgs.extend self.overlays.default).riscal.outPath == riscal.outPath;
          pkgs.runCommand "check-riscal-flake-interface" { } ''
            touch "$out"
          '';
      };

      formatter.${system} = pkgs.nixfmt-tree;
    };
}
