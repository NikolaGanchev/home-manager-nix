{
    description = "Home manager";

    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    };

    outputs = { self, nixpkgs }: {
        lib = {
            makeHome = { pkgs, configuration }:
                import ./lib/evaluateConfig.nix {
                    inherit pkgs configuration;
                    lib = nixpkgs.lib;

                    genericModule = ./modules/generic.nix;
                };
        };

        nixosModules.default = import ./nixosModule.nix;
    };
}