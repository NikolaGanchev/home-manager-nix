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
    #TODO
fi