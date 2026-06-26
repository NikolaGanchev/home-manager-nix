{ config, lib, pkgs, ...}: {
    options.home-manager2 = {
        profiles = lib.mkOption {
            type = lib.types.attrsOf (lib.types.submodule ({config, ...}: {
                options = {
                    config = lib.mkOption {
                        type = lib.types.attrsOf lib.types.attrs;
                        default = {};
                    };

                    enable = lib.mkOption {
                        type = lib.types.bool;
                    };

                    username = lib.mkOption {
                        type = lib.types.str;
                    };

                    home = lib.mkOption {
                        type = lib.types.path;
                        default = "/home/${config.user}";
                    };
                };
            }));
            
        };

        extraModules = lib.mkOption {
            type = lib.types.listOf lib.types.unspecified;
            default = [];
            description = "A list of modules to inject in user configurations";
        };
    };

    config = {
        home-manager2.extraModules = [ ./modules/git.nix ];

        system.activationScripts.home-manager2-activate = lib.concatStringsSep "\n" (
            lib.mapAttrsToList (profile: profileConfig: 
                let pkg = import ./lib/evaluateConfig.nix { 
                    inherit pkgs lib; 
                    configuration = profileConfig.config; 
                    genericModule = ./modules/generic.nix; 

                    extraModules = config.home-manager2.extraModules;
                }; 
                in ''
                    echo "Activating home-manager2 for user ${profileConfig.username}"
                    runuser -u ${profileConfig.username} -- env HOME="${config.users.users.${profileConfig.username}.home}" USER="${profileConfig.username}" "${pkg}/commit"
                '') (lib.attrsets.filterAttrs (name: value: value.enable) config.home-manager2.profiles)
        );
    };
}