{ config, lib, pkgs, ...}:
    let 
        cfg = config.programs.git;
    in { 
    options = {
        programs.git.attributes = lib.mkOption {
            description = "A list of global git attributes";
            default = [];
            type = lib.types.listOf lib.types.str;
        };

        programs.git.enable = lib.mkOption {
            description = "Whether git is enabled";
            default = false;
            type = lib.types.bool;
        };

        programs.git.config = lib.mkOption {
            description = "Attribute set used to generate the .gitconfig file";
            default = {};
            type = lib.types.attrs;
        };

        programs.git.lfs.enable = lib.mkOption {
            description = "Whether git lfs is enabled";
            default = false;
            type = lib.types.bool;
        };

        programs.git.lfs.enablePureSSHTransfer = lib.mkOption {
            description = "Whether git pure SSH transfer is enabled";
            default = false;
            type = lib.types.bool;
        };

        programs.git.lfs.package = lib.mkOption {
            description = "The git lfs package";
            default = pkgs.git-lfs;
            type = lib.types.package;
        };

        programs.git.package = lib.mkOption {
            description = "The git package";
            default = pkgs.git;
            type = lib.types.package;
        };

        programs.git.prompt.enable = lib.mkOption {
            description = "Whether to enable automatically sourcing git-prompt.sh.";
            default = false;
            type = lib.types.bool;
        };
    };

    config = lib.mkMerge [
        (lib.mkIf cfg.enable {
            home.file.".gitconfig".text = lib.generators.toGitINI cfg.config;

            home.file.".config/git/attributes" = lib.mkIf (cfg.attributes != []) {
                text = lib.concatStringsSep "\n" cfg.attributes + "\n";
            };
        })

        (lib.mkIf (cfg.enable && cfg.lfs.enable) {
            programs.git.config = {
                filter.lfs = {
                    clean = "git-lfs clean -- %f";
                    smudge = "git-lfs smudge -- %f";
                    process = "git-lfs filter-process";
                    required = true;
                };
            };
        })

        (lib.mkIf (cfg.enable && cfg.lfs.enable && cfg.lfs.enablePureSSHTransfer) {
            programs.git.config = {
                lfs."customtransfer.pure-ssh" = {
                    path = "git-lfs-authenticate";
                    args = "pure-ssh";
                };
            };
        })

        (lib.mkIf (cfg.enable && cfg.prompt.enable) {
            home.file.".config/git/git-prompt.sh" = {
                source = "${cfg.package}/share/git/contrib/completion/git-prompt.sh";
            };
        })
    ];
}