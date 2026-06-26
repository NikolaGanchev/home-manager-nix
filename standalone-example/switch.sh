nix flake update --extra-experimental-features "nix-command flakes"

nix build .#default --extra-experimental-features "nix-command flakes"

./result/commit