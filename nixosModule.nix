{ config, lib, pkgs, ...}: {
    options.home-manager2.users = lib.mkOption {
        type = lib.types.attrsOf lib.types.attrs;
        default = {};
    };

    config = {
        system.activationScripts.home-manager2-activate = lib.concatStringsSep "\n" (
            lib.mapAttrsToList (username: userConfig: ''
                echo "Activating home-manager2 for user $username"
                su - ${username} -c "${import ./lib/evaluateConfig.nix { inherit pkgs lib; configuration = userConfig; genericModule = ./modules/generic.nix; } }/commit"
            '') config.home-manager2.users
        );
    };
}