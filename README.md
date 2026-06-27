## Overview

A Nix Home Manager clone, created for educational purposes.

## Setup
Supports both NixOS modules and standalone usage via the Nix package manager.

### NixOS usage
Using flakes, add the library:
```nix
inputs.home-manager2.url = "github:NikolaGanchev/home-manager-nix/main
```

 After that, you can use the provided `nixosModule` by simply adding it along your other modules in your `nixpkgs.lib.nixosSystem`:

```nix
    modules = [
        ...
        home-manager2.nixosModules.default
        ({config, pkgs, ...}): {
            home-manager2.users.user1 = {
                activeProfile = "default";
                profiles.default = {
                    home.file."./config/file1".text = "1";
                    home.file."./config/file2".text = "2";
                };
                profiles.sourced = {
                    home.file."./config/file1".source = ./file3;
                    home.file."./config/file2".text = "1";
                };
                home = "/home/user1";
            };
            home-manager2.users.user2.profiles.fancy = {
                home.file."./config/fancy".text = "";
            };

            home-manager2.extraModules = [ home-manager2.modules.git ];
        };
```

A `nixos-rebuild switch` will apply the new `home` configuration.

Notice that this configuration allows multiple users to be configured. Furthermore, every user can have multiple separate profiles, only one of which is active at a time. 

The options `activeProfile` and `home` are unique to the NixOS module.

The `activeProfile` option is resolved by the following rules:
- if `activeProfile` is user set, the user value is used. 
    - if the value is null, the user is ignored. 
    - if the value is not a valid profile, an error is thrown.
    - otherwise, the given profile is used.
- if `activeProfile` is not set:
    - if the user has no profile, the value is set to null and is ignored.
    - if there is only one profile for the user, it will be used, but a warning will be shown.
    - if there is more than one profile, an error will be thrown.

Users can also override their `home` paths. By default, the `home` path is derived via the `username`, as per `/home/${username}`. By default, this is wrong for macOS configs, nested `/home` structures and other non-standard structure.

### Standalone usage

Configure your `flake.nix` via the provided lib.makeHome function:

```nix
{
    inputs.home-manager2.url = "github:NikolaGanchev/home-manager-nix/main";
    inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

    outputs = {nixpkgs, home-manager2, ...}:
        {
            packages."${YOUR_SYSTEM}".default = home-manager2.lib.makeHome {
                pkgs = nixpkgs.legacyPackages."${YOUR_SYSTEM}";
                configuration = {
                    home.file."./config/file1".text = "1";
                    home.file."./config/file2".text = "2";

                    programs.git = {
                        enable = true;
                        prompt.enable = true;
                        config = {
                            user.name = "username";
                            user.email = "email";
                            init.defaultBranch = "main";
                        };
                    };
                };
                extraModules = [ home-manager2.modules.git ];
            };
        };
}
```

Standalone configurations work based on generations. Every time a configuration is applied, it creates a new generation in the `$HOME/.local/state/home-manager2/generations` folder. THe generations are the built Nix output for the configuration. Their names are of the form `generation-%Y%m%d_%H%M%S`, with `/current` being a symlink to the currently applied generation.

Then, you can invoke the CLI via the command in the directory of your `flake.nix`:
```bash
nix run github:NikolaGanchev/home-manager-nix/main -- switch
```
which will perform a switch to the new configuration.

Nix will not generate a new build output for the same configuration if it has previously been built. If the configuration being applied is identical with the one that is current, then `switch` will do nothing. If an already existing generation is identical to the new one, it will switch to it instead of creating a new entry.

Other available commands are:
- list-generations: lists the generations for this user.
- rollback [n]: switches to the n-th previous generation. If n is not specified, the previous generation is used. Does not affect the source of the configuration.
- rollback-named <name>: switches to a generation by its exact name. Does not affect the source of the configuration.
- collect-garbage <n>: deletes all generations except the last n.

## General function
This is general information that applies to both usage methods.

A configuration takes the form of an attribute set:

```nix
configuration = {
    home.file."./config/file2".text = "1";
    home.file."./config/file1".source = ./file3;
};
```

Each attribute of the type `home.file.<path>` represents a file that will be put in the `home` directory of the user. It may set either `text` or `source` but not both and not neither.

The library functions by iterating over this set and creating a static file structure representing the home directory in the final package. It also creates a `commit` script. Upon running the `commit` script, it does the following:
1. Checks if the `$HOME/.local/state/home-manager2/administered-files` file exists.
    - If it does, it must contain one file on each line which a previous run has created. The script iterates over every of those files, and if it is not declared in the current configuration and is a symlink to some object in `/nix/store`, it is removed.
    - Otherwise, creates the file.
2. Iterates over the file structure generated previously. For every file:
    - if a file with the same name and path exists in the `home` directory and
        - that file is a symlink to some object in `/nix/store`, it is replaced with a symlink to the new file.
        - that file is not a symlink to some object in `/nix/store`, an error is triggered and the user must resolve the conflict.
    - if a file with the same name and path does not exist in the `home` directory, a symlink to the new file is created with that path and name.
3. Records the symlinks it has written to `$HOME/.local/state/home-manager2/administered-files`.

## Extending
Custom modules can be defined that exports options and the appropriate config to generate configuration files according to those options. A provided example is the `git` module. It defines how the standard `programs.git` options should influence the `home` directory state, allowing easy definitions:

```nix
outputs = {nixpkgs, home-manager2, ...}:
        {
            packages."${YOUR_SYSTEM}".default = home-manager2.lib.makeHome {
                pkgs = nixpkgs.legacyPackages."${YOUR_SYSTEM}";
                configuration = {
                    programs.git = {
                        enable = true;
                        prompt.enable = true;
                        attributes = ["*.pdf" "diff=pdf"];
                        programs.git.lfs = {
                            enable = true;
                            enablePureSSHTransfer = true;
                            package = pkgs.git-lfs;
                        };
                        config = {
                            user.name = "username";
                            user.email = "email";
                            init.defaultBranch = "main";
                        };
                    };
                };
                extraModules = [ home-manager2.modules.git ];
            };
        };
```