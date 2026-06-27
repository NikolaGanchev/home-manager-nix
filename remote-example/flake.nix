{
    inputs.home-manager2.url = "github:NikolaGanchev/home-manager-nix/main";
    inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

    outputs = {nixpkgs, home-manager2, ...}:
        {
            packages."aarch64-linux".default = home-manager2.lib.makeHome {
                pkgs = nixpkgs.legacyPackages."aarch64-linux";
                configuration = {
                    home.file.".config/notification2" = {
                        text = "1";
                    };
                    
                    home.file.".config/fold1/notification" = {
                        text = "2";
                    };

                    home.file.".config/external1" = {
                        source = ./flake.nix; # this file
                    };

                    programs.git = {
                        enable = true;
                        prompt.enable = true;
                        config = {
                            user.name = "username";
                            user.email = "email";
                            init.defaultBranch = "main";
                        };
                    };
                };
                extraModules = [ home-manager2.modules.git ];
            };
        };
}