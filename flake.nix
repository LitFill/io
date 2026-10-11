{
  description = "Io language VM — WASM build via wasi-sdk";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      # Host toolchain for the build: gcc (host io2c generator),
      # gnumake, wasmtime (test runner). The WASM cross-compiler
      # (wasi-sdk) is vendored at ../wasi-sdk; pass it via
      # `make WASI_SDK=../wasi-sdk`.
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          gcc
          gnumake
          wasmtime
        ];
      };
    };
}
