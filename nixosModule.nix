{ config, lib, pkgs, ...}: {
    options.home-manager2 = {
        users = lib.mkOption {
            type = lib.types.attrsOf (lib.types.submodule ({name, config, ...}: {
                options = {
                    profiles = lib.mkOption {
                        type = lib.types.attrsOf lib.types.attrs;
                        default = {};
                        description = "Named configurations";
                    };

                    home = lib.mkOption {
                        type = lib.types.path;
                        default = "/home/${name}";
                        description = "The path to the home directory";
                    };

                    activeProfile = lib.mkOption {
                        description = "The profile that will be used by the user";
                        type = lib.types.nullOr lib.types.str;
                        default = 
                            let 
                                profileNames = builtins.attrNames config.profiles;
                                profileCount = builtins.length profileNames;
                            in
                                if profileCount == 1 then
                                    builtins.trace ''
                                        home-manager2: No explicit 'activeProfile' for user '${name}'.
                                        Single profile found and selected: '${builtins.head profileNames}' ''
                                    builtins.head profileNames
                                else if profileCount > 1 then
                                    builtins.throw ''
                                        home-manager2: Ambiguous configuration for user '${name}'.
                                        Found ${toString profileCount} profiles: ${lib.concatStringsSep ", " profileNames}.
                                        '${name}.activeProfile' must be explicitly set.''
                                else null;
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
            lib.mapAttrsToList (user: userConfig: 
                let 
                    pkg = import ./lib/evaluateConfig.nix { 
                        inherit pkgs lib; 
                        configuration = userConfig.profiles."${userConfig.activeProfile}"; 
                        genericModule = ./modules/generic.nix; 

                        extraModules = config.home-manager2.extraModules;
                    }; 
                in 
                    if !(builtins.hasAttr userConfig.activeProfile userConfig.profiles) then
                        builtins.throw "home-manager2: Specified 'activeProfile' '${userConfig.activeProfile}' for user '${user}' does not exist."
                    else
                    ''
                        echo "home-manager2: Activating profile '${userConfig.activeProfile}' for user ${user}"
                        runuser -u ${user} -- env HOME="${userConfig.home}" USER="${user}" "${pkg}/commit"
                    '') (lib.attrsets.filterAttrs (name: value: value.activeProfile != null) config.home-manager2.users)
        );
    };
}