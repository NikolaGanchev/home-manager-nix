{
    description = "Home manager";

    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    };

    outputs = { self, nixpkgs }: {
        modules = {
            generic = ./modules/generic.nix;
            git = ./modules/git.nix;
        };

        lib = {
            makeHome = { pkgs, configuration, extraModules ? [] }:
                import ./lib/evaluateConfig.nix {
                    inherit pkgs configuration extraModules;
                    lib = nixpkgs.lib;

                    genericModule = self.modules.generic;
                };
        };

        nixosModules.default = import ./nixosModule.nix;
    };
}