{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

    # Version of requirements.txt installed in pythonEnv
    zephyr.url = "github:zephyrproject-rtos/zephyr/v3.5.0";
    zephyr.flake = false;

    # Zephyr sdk and toolchain
    zephyr-nix.url = "github:urob/zephyr-nix";
    zephyr-nix.inputs.zephyr.follows = "zephyr";
    # Relies on 23.11 to provide py38 until zephyr-sdk bumps the requirement
    # https://github.com/zephyrproject-rtos/sdk-ng/issues/752
    # zephyr-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { nixpkgs, zephyr-nix, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          zephyr = zephyr-nix.packages.${system};
          keymap_drawer = pkgs.python3Packages.callPackage ./draw { };

        in
        {
          default = pkgs.mkShell {
            packages = [
              keymap_drawer

              zephyr.pythonEnv
              (zephyr.sdk.override { targets = [ "arm-zephyr-eabi" ]; })

              pkgs.cmake
              pkgs.dtc
              pkgs.ninja
              pkgs.qemu # needed for native_posix target

              pkgs.just
              pkgs.yq
              pkgs.watchexec
            ];
          };
        }
      );
    };
}
