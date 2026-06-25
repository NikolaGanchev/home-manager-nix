{ pkgs, lib, configuration, genericModule, extraModules ? [] }:

let 
    result = lib.evalModules {
        modules = [
            configuration
            genericModule
        ] ++ extraModules;
        specialArgs = { inherit pkgs; };
    };
in
result.config.build.commitPackage