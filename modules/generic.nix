{ config, lib, pkgs, ...}: {
    options = {
        home.file = lib.mkOption {
            description = "Attribute set of files to place in the home directory";
            default = {};
            type = lib.types.attrsOf (lib.types.submodule {
                options = {
                    text = lib.mkOption {
                        type = lib.types.nullOr lib.types.str;
                        default = null;
                        description = "The text content of the file";
                    };

                    source = lib.mkOption {
                        type = lib.types.nullOr lib.types.path;
                        default = null;
                        description = "Path to a local file or directory to symlink";
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

                        ${if filedef.source != null then 
                            ''cp -r ${filedef.source} "$out/${path}"''
                        else if filedef.text != null then 
                            ''echo -n ${lib.escapeShellArg filedef.text} > "$out/${path}"''
                        else ''echo "home-manager2: Neither text nor source provided for ${path}" >&2''}
                    '') config.home.file)}
            '';
            commitFiles = pkgs.writeShellScript "commit" ''
                echo "Commiting files to $HOME"

                cd ${homeFiles}

                # TODO
                while read -r file; do 
                    target="$HOME/$file"
                    source="${homeFiles}/$file"

                    if [ -e "$target" ] || [ -L "$target" ]; then
                        if [ -L "$target" ]; then
                            dest=$(readlink "$target")

                            if [[ "$dest" == /nix/store/* ]]; then
                                echo "home-manager2: Removing old symlink '$target' to '$dest'"
                                rm "$target"
                            else
                                echo "home-manager2: Collision detected." >&2
                                echo "'$target' already points to '$dest'" >&2
                                exit 1
                            fi
                        else
                            echo "home-manager2: Collision detected." >&2
                            echo "$target is a file that is not administered by home-manager2" >&2
                            exit 1
                        fi
                    fi

                    echo "home-manager2: Symlinking '$target' to '$source'"
                    mkdir -p "$(dirname "$target")"
                    ln -s "$source" "$target"
                done < <(find . -type f -printf "%P\n")

                echo "$HOME populated"
            '';
        in pkgs.runCommand "home-manager-generation" {} ''
            mkdir -p $out
            ln -s ${homeFiles} $out/home-manager2-files
            ln -s ${commitFiles} $out/commit
        '';
    };
}