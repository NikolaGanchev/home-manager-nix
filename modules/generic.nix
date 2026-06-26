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
                echo "home-manager2: Commiting files to $HOME"

                cd ${homeFiles}

                state_dir="$HOME/.local/state/home-manager2"
                state_file="$state_dir/administered-files"
                mkdir -p "$state_dir"

                if [ -f "$state_file" ]; then
                    while read -r old_file; do
                        # does not exist in this generation
                        if [ ! -e "$old_file" ]; then

                            target="$HOME/$old_file"
                            dest="$(readlink "$target")"
                            if [ -L $target ] && [[ "$dest" == /nix/store/* ]]; then
                                echo "home-manager2: Removing orphaned symlink '$target'"
                                rm "$target"

                                rmdir --ignore-fail-on-non-empty -p "$(dirname "$target")" 2>/dev/null || true
                            fi
                        fi
                    done < "$state_file"
                fi

                rm -f "$state_file"

                while read -r file; do 
                    target="$HOME/$file"
                    source="${homeFiles}/$file"

                    if [ -e "$target" ] || [ -L "$target" ]; then
                        if [ -L "$target" ]; then
                            dest="$(readlink "$target")"

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

                    echo "$file" >> "$state_file"
                done < <(find . -type f -printf "%P\n")

                echo "home-manager2: $HOME populated"
            '';
        in pkgs.runCommand "home-manager-generation" {} ''
            mkdir -p $out
            ln -s ${homeFiles} $out/home-manager2-files
            ln -s ${commitFiles} $out/commit
        '';
    };
}