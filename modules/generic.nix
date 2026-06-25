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
            homeFiles = pkgs.runCommand "home-manager2-files" {} ''
                mkdir -p $out

                ${lib.concatStringsSep "\n" 
                    (lib.mapAttrsToList (path: filedef: ''
                        mkdir -p $(dirname "$out/${path}")
                        echo -n ${lib.escapeShellArg filedef.text} > "$out/${path}"
                        echo "Put ${lib.escapeShellArg filedef.text} into $out/${path}"
                    '') config.home.file)}
            '';
            commitFiles = pkgs.writeShellScript "commit" ''
                echo "Commiting files to $HOME"

                cd ${homeFiles}

                # TODO
                find . -type f -printf "%P\n" | while read -r file; do 
                    target="$HOME/$file"
                    source="${homeFiles}/$file"
                    echo "home-manager2: Target $target"
                    echo "home-manager2: Source $source"
                    echo "home-manager2: Symlinking"
                    mkdir -p "$(dirname "$target")"
                    ln -s "$source" "$target"
                done

                echo "$HOME populated"
            '';
        in pkgs.runCommand "home-manager-generation" {} ''
            mkdir -p $out
            ln -s ${homeFiles} $out/home-manager2-files
            ln -s ${commitFiles} $out/commit
        '';
    };
}