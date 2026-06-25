{ config, lib, pkgs, ...}: {
    options.home-manager2.users = lib.mkOption {
        type = lib.types.attrsOf lib.types.attrs;
        default = {};
    };

    config = {
        system.activationScripts.home-manager2-activate = lib.concatStringsSep "\n" (
            lib.mapAttrsToList (username: userConfig: 
            let pkg = import ./lib/evaluateConfig.nix { 
                inherit pkgs lib; 
                configuration = userConfig; 
                genericModule = ./modules/generic.nix; 
            }; 
            in ''
                echo "Activating home-manager2 for user $username"
                runuser -u ${username} -- "${pkg}/commit"
            '') config.home-manager2.users
        );
    };
}