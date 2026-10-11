{
  description = "Io language VM — WASM build via wasi-sdk";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # WASM cross-compiler, pinned to the official wasi-sdk 34.0
      # release (clang/LLVM 23.1.0):
      # https://github.com/WebAssembly/wasi-sdk/releases/tag/wasi-sdk-34
      # The release tarball links against the build host's libstdc++
      # and libtinfo; autoPatchelf gives those tools nix-store
      # rpaths so they run inside the build sandbox.
      wasi-sdk = pkgs.stdenv.mkDerivation (final: {
        pname = "wasi-sdk";
        version = "34.0";
        src = pkgs.fetchurl {
          url = "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-34/wasi-sdk-34.0-x86_64-linux.tar.gz";
          hash = "sha256-t2HjoHIduunAmgBZ5f2yv5F9G0qKe0MPs7Wq+wmEssQ=";
        };
        sourceRoot = "wasi-sdk-34.0-x86_64-linux";
        nativeBuildInputs = [ pkgs.autoPatchelfHook ];
        buildInputs = [ pkgs.stdenv.cc.cc.lib pkgs.libtinfo ];
        dontConfigure = true;
        dontBuild = true;
        installPhase = ''
          mkdir -p $out
          cp -r ./* $out/
        '';
      });

      # deps/parson is a git submodule, which flake source filters drop;
      # fetch it at the pinned revision instead.
      parson = pkgs.fetchurl {
        url = "https://github.com/kgabis/parson/archive/ec53fb6528b45811df9db0db22cab96a94a96a11.tar.gz";
        hash = "sha256-nKVbGVOaAZ3YYjRUOpZb5FM75gCo0lOdAEYyKIjfSkE=";
      };
    in {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          pkgs.gcc
          pkgs.gnumake
          pkgs.wasmtime
          wasi-sdk
        ];

        # The Makefile defaults WASI_SDK to $(HOME)/wasi-sdk; an
        # environment variable takes precedence, so plain `make` works
        # in this shell.
        WASI_SDK = wasi-sdk;
      };

      packages.${system}.default = pkgs.stdenv.mkDerivation {
        pname = "io";
        version = "20260302";
        src = ./.;
        nativeBuildInputs = [ pkgs.gnumake pkgs.makeWrapper wasi-sdk ];
        buildPhase = ''
          cp -r $src/* .
          mkdir -p deps/parson
          tar -xf ${parson} -C deps/parson --strip-components=1
          make regenerate
          make WASI_SDK=${wasi-sdk}
        '';
        installPhase = ''
          install -Dm755 build/bin/io_static $out/bin/io_static
          # io_static is a WASM module; `io` runs it under wasmtime.
          makeWrapper ${pkgs.wasmtime}/bin/wasmtime $out/bin/io \
            --add-flags $out/bin/io_static
        '';
      };
    };
}
