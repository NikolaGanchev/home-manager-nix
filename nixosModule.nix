{ config, lib, pkgs, ...}: {
    options.home-manager2 = {
        users = lib.mkOption {
            type = lib.types.attrsOf lib.types.attrs;
            default = {};
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
            lib.mapAttrsToList (username: userConfig: 
            let pkg = import ./lib/evaluateConfig.nix { 
                inherit pkgs lib; 
                configuration = userConfig; 
                genericModule = ./modules/generic.nix; 

                extraModules = config.home-manager2.extraModules;
            }; 
            in ''
                echo "Activating home-manager2 for user ${username}"
                runuser -u ${username} -- env HOME="${config.users.users.${username}.home}" USER="${username}" "${pkg}/commit"
            '') config.home-manager2.users
        );
    };
}