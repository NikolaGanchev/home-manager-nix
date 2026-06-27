#!/usr/bin/env bash
set -eo pipefail

command=$1

if [ "$command" != "switch" ] && [ "$command" != "collect-garbage" ]; then
    echo "home-manager2: Run this command inside the directory of your flake.nix"
    echo "Commands:"
    echo "switch: switches the current configuration"
    echo "collect-garbage n: deletes all generations except the last n"
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

timestamp=$(date +%Y%m%d_%H%M%S)
generation_path="$generations_dir/generation-$timestamp"

mv ./result "$generation_path"

ln -sfn "$generation_path" "$generations_dir/current"

echo "home-manager2: Build successful. Proceeding to activation."

"$generations_dir/current/commit"

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

        if [ "$(readlink -f "$gen_to_delete")" == "$current_target" ]; then
            continue
        fi

        echo "Deleting $(basename "$gen_to_delete")"
        rm -rf "$gen_to_delete"
    done

    echo "home-manager2: Garbage collection successful."
fi