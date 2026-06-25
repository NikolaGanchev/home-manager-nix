{ config, lib, pkgs, ...}: {
    options = {
        home.file = lib.mkOption {
            description = "Attribute set of files to place in the home directory";
            default = {};
            type = lib.types.attrsOf (lib.types.submodule {
                options = {
                    text = lib.mkOption {
                        type = lib.types.str;
                        default = "";
                        description = "The text content of the file";
                    };
                };
            });
        };

        build.commitPackage = lib.mkOption {
            type = lib.types.package;
        };
    };

    config = {
        build.commitPackage = let 
            makeFiles = pkgs.runCommand "make-files" {} ''
                mkdir -p $out

                ${lib.concatStringsSep "\n" 
                    (lib.mapAttrsToList (path: filedef: ''
                        mkdir -p $(dirname "$out/${path}")
                        echo -n ${lib.escapeShellArg filedef.text} > "$out/${path}"
                    '') config.home.file)}
            '';
            commitFiles = pkgs.writeShellScript "commit" ''
                echo "Commiting files to $HOME"

                cd ${makeFiles}

                # TODO
                touch "$HOME/notification"

                echo "$HOME populated"
            '';
        in pkgs.runCommand "home-manager-generation" {} ''
            mkdir -p $out
            ln -s ${makeFiles} $out/make-files
            ln -s ${commitFiles} $out/commit
        '';
    };
}