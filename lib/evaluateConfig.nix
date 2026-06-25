{ pkgs, lib, configuration, genericModule }:

let 
    result = lib.evalModules {
        modules = [
            configuration
            genericModule
        ];
        specialArgs = { inherit pkgs; };
    };
in
result.config.build.commitPackage