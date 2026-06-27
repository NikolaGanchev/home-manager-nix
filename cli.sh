#!/usr/bin/env bash
set -eo pipefail

command=$1

if [ "$command" != "switch" ] && [ "$command" != "collect-garbage" ] && [ "$command" != "rollback" ] && [ "$command" != "rollback-named" ] && [ "$command" != "list-generations" ]; then
    echo "home-manager2: Run this command inside the directory of your flake.nix"
    echo "Commands:"
    echo "switch: switches the current configuration"
    echo "list-generations: lists the generations for this user"
    echo "rollback [n]: switches to the n-th previous generation. If n is not specified, the previous generation is used. Does not affect the source of the configuration"
    echo "rollback-named <name>: switches to a generation by its exact name. Does not affect the source of the configuration."
    echo "collect-garbage <n>: deletes all generations except the last n"
    exit 1
fi

state_dir="$HOME/.local/state/home-manager2"
generations_dir="$state_dir/generations"

if [ "$command" == "switch" ]; then
    mkdir -p "$generations_dir"

    echo "home-manager2: Building configuration"

    if ! nix build .#default --out-link ./result --extra-experimental-features "nix-command flakes"; then
        echo "home-manager2: Build failed."
        exit 1
    fi

    if [ -d "$generations_dir" ]; then
        new=$(readlink -f ./result/commit)

        while read -r gen; do
            if [ "$new" == "$(readlink -f "$gen/commit")" ]; then

                if [ -L "$generations_dir/current" ]; then

                    if [ "$new" == "$(readlink -f "$generations_dir/current/commit")" ]; then
                        echo "home-manager2: Already at this configuration."
                        rm ./result
                        exit 0
                    fi
                fi

                echo "home-manager2: Already have this configuration as $(basename "$gen"). Switching..."
                ln -sfn "$gen" "$generations_dir/current"
                "$generations_dir/current/commit"
                rm ./result
                exit 0
            fi
        done < <(find "$generations_dir" -maxdepth 1 -name "generation-*")
    fi

    timestamp=$(date +%Y%m%d_%H%M%S)
    generation_path="$generations_dir/generation-$timestamp"

    mv ./result "$generation_path"

    ln -sfn "$generation_path" "$generations_dir/current"

    echo "home-manager2: Build successful. Proceeding to activation."

    "$generations_dir/current/commit"

elif [ "$command" == "rollback" ]; then 
    n=${2:-1}

    if [[ -z "$n" ]] || ! [[ "$n" =~ ^[0-9]+$ ]] || [ "$n" -lt 1 ]; then
        echo "home-manager2: 'rollback' requires a positive integer argument"
        exit 1
    fi

    if [ ! -d "$generations_dir" ]; then
        echo "home-manager2: No generations directory found. Nothing to rollback"
        exit 1
    fi

    mapfile -t generations < <(find "$generations_dir" -maxdepth 1 -name "generation-*" | sort)
    gen_count=${#generations[@]}

    if [ "$gen_count" -lt $((n + 1)) ]; then
        echo "home-manager2: Cannot roll back $n generations. Only $gen_count generations exist."
        exit 0
    fi

    target="${generations[$((gen_count - 1 - n))]}"

    echo "home-manager2: Rolling back $n generations to '$(basename "$target")'"
    ln -sfn "$target" "$generations_dir/current"
    "$generations_dir/current/commit"

elif [ "$command" == "rollback-named" ]; then
    name=$2

    if [[ -z "$name" ]]; then
        echo "home-manager2: 'rollback-name' requires a generation name argument"
        exit 1
    fi

    if [ ! -d "$generations_dir" ]; then
        echo "home-manager2: No generations directory found. Nothing to rollback"
        exit 1
    fi

    target="$generations_dir/$name"

    if [ ! -d "$target" ]; then
        echo "home-manager2: Generation '$name' not found."
        exit 1
    fi

    echo "home-manager2: Rolling back to '$name'"
    ln -sfn "$target" "$generations_dir/current"
    "$generations_dir/current/commit"

elif [ "$command" == "list-generations" ]; then

    if [ ! -d "$generations_dir" ]; then
        echo "home-manager2: No generations directory found."
        exit 1
    fi

    current_generation=$(readlink -f "$generations_dir/current" 2>/dev/null)
    
    while read -r gen; do
        name=$(basename "$gen")
        if [ "$(readlink -f "$gen")" == "$current_generation" ]; then
            echo "$name (current)"
        else
            echo "$name"
        fi
    done < <(find "$generations_dir" -maxdepth 1 -name "generation-*" | sort -r)

elif [ "$command" == "collect-garbage" ]; then 
    keepn=$2

    if [[ -z "$keepn" ]] || ! [[ "$keepn" =~ ^[0-9]+$ ]] || [ "$keepn" -lt 1 ]; then
        echo "home-manager2: 'collect-garbage' requires a positive integer argument"
        exit 1
    fi

    if [ ! -d "$generations_dir" ]; then
        echo "home-manager2: No generations directory found. Nothing to do"
        exit 0
    fi

    mapfile -t generations < <(find "$generations_dir" -maxdepth 1 -name "generation-*" | sort)
    gen_count=${#generations[@]}

    if [ "$gen_count" -le "$keepn" ]; then
        echo "home-manager2: Found only $gen_count generations, which is less than or equal to the given argument $keepn."
        exit 0
    fi

    delete_count=$((gen_count - keepn))
    current_generation=$(readlink -f "$generations_dir/current" 2>/dev/null)

    echo "home-manager2: Keeping the last $keepn generations. Deleting $delete_count old generations."

    for (( i = 0; i < delete_count; i++ )); do
        gen_to_delete="${generations[$i]}"

        if [ "$(readlink -f "$gen_to_delete")" == "$current_generation" ]; then
            continue
        fi

        echo "Deleting $(basename "$gen_to_delete")"
        rm -rf "$gen_to_delete"
    done

    echo "home-manager2: Garbage collection successful."
fi