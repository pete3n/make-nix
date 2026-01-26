# users directory
## Purpose
    - Organize Home-manager configurations and user configuration files

## Directory structure
users/<username> -- individual user level configuration files
├── darwin-user.nix -- system level user configuration for Darwin based hosts
├── linux-user.nix -- system level user configuration for Linux based hosts
├── home-manager -- Nix home-manager configuration files
│   ├── button.d.ts
│   ├── button.js
│   ├── button.js.map
│   ├── button.stories.d.ts
│   ├── button.stories.js
│   ├── button.stories.js.map
│   ├── index.d.ts
│   ├── index.js
│   └── index.js.map
├── package.json
├── src
│   ├── button.stories.tsx
│   ├── button.tsx
│   └── index.ts
└── tsconfig.json
    - darwin_user.nix -- system level user configuration for Darwin based hosts
    - linux_user.nix -- system level user configuration for Linux based hosts
        -  


    - User configurations can apply to any system
    
