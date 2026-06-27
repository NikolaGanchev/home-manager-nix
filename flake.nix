{
    description = "Home manager";

    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    };

    outputs = { self, nixpkgs }: 
    let 
        systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin"];
    in
    {
        modules = {
            generic = ./modules/generic.nix;
            git = ./modules/git.nix;
        };

        packages = nixpkgs.lib.genAttrs systems (system: {
                default = nixpkgs.legacyPackages.${system}.writeShellScriptBin "home-manager2" (builtins.readFile ./cli.sh);
            }
        );

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