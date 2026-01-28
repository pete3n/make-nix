# users directory
## Purpose
    - Organize Home-manager configurations and user configuration files

## Directory structure
users/<username> -- individual user level configuration files
├── darwin-user.nix -- system level user configuration for Darwin based hosts
├── linux-user.nix -- system level user configuration for Linux based hosts
├── home-manager -- Nix Home-manager configuration files
│   ├── cross-platform -- Home-manager configuration files compatible with both Linux and Darwin
│   │   ├── <application-config.nix> -- Application specific config for user
│   ├── darwin -- Home-manager configuration files only used on Darwin systems
│   │   ├── <application-config.nix> -- Application specific config for user
│   └── linux -- Home-manager configuration files only used on Linux systems
│       └── <application-config.nix> -- Application specific config for user
└─── secrets -- User specific secrets files (no private keys) 
     └── <keyfile> -- Decryption information needed for things like Yubikeys
