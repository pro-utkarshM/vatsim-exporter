{
  description = "VATSIM Prometheus Exporter";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
    utils.url = "github:numtide/flake-utils";
    argocd-nix-flakes-plugin = {
      url = "github:mayflower/argocd-nix-flakes-plugin";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "utils";
    };
    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "utils";
    };
  };

  outputs = { self, nixpkgs, utils, crane, argocd-nix-flakes-plugin, ... }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        craneLib = crane.lib.${system};

        src = craneLib.cleanCargoSource ./.;
        cargoArtifacts = craneLib.buildDepsOnly {
          inherit src; pname = "vastsim-exporter";
        };
        vatsim-exporter = craneLib.buildPackage {
          inherit src cargoArtifacts;
        };
      in
      {
        inherit pkgs;
        packages = {
          default = vatsim-exporter;

          dockerImages = {
            vatsim-exporter = pkgs.dockerTools.buildImage {
              name = "vatsim-exporter";
              tag = "latest";
              copyToRoot = [ vatsim-exporter ];

              config = {
                Cmd = [ "/bin/vatsim-exporter" ];
                ExposedPorts."9185/tcp" = {};
              };
            };
          };
        };

        apps = {
          inherit (argocd-nix-flakes-plugin.apps.${system}) tankaShow tankaEval;
        };

        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            cargo
            cargo-watch
            jsonnet
            jsonnet-bundler
            rust-analyzer
            rustPackages.clippy
            rustc
            rustfmt
            sops
            tanka
          ];
          RUST_SRC_PATH = pkgs.rustPlatform.rustLibSrc;
        };
      });
}
