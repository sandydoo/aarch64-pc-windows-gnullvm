{
  description = "Cross compiling a Rust program for ARM Windows";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";

    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, crane, rust-overlay, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        target = "aarch64-pc-windows-gnullvm";

        # LLVM-based toolchain 
        llvmMingw = pkgs.stdenv.mkDerivation {
          name = "llvm-mingw";
          src = pkgs.fetchurl {
            url = "https://github.com/mstorsjo/llvm-mingw/releases/download/20220906/llvm-mingw-20220906-ucrt-ubuntu-18.04-aarch64.tar.xz";
            hash = "sha256-9J/v7DWo1QtCwDKMJ3x/diipgGYW8tLyYbhyuVO+kFY=";
          };
          nativeBuildInputs = [ pkgs.autoPatchelfHook ];
          buildInputs = [ pkgs.stdenv.cc.cc.lib ];
          dontStrip = true;
          installPhase = ''
            mkdir $out
            cp -r * $out
          '';
        };

        overlays = [ (import rust-overlay) ];
        pkgs = (import nixpkgs) {
          inherit system overlays;
        };

        # Nightly required for build-std
        toolchain = pkgs.rust-bin.nightly.latest.default.override {
          extensions = [ "rust-src" ];
        };

        craneLib = (crane.mkLib pkgs).overrideToolchain toolchain;
      in
      {
        packages.default = craneLib.buildPackage {
          src = craneLib.cleanCargoSource ./.;

          strictDeps = true;
          doCheck = false;

          CARGO_BUILD_TARGET = target;

          # BROKEN: requires network access
          cargoExtraArgs = "-Z build-std";

          depsBuildBuild = [
            llvmMingw
          ];
        };

        # Works manually
        # cargo build --target aarch64-pc-windows-gnullvm -Z build-std
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = [
            toolchain
            llvmMingw
          ];
        };
      }
    );
}
