<div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap;">
  <h1 style="margin: 0;">Make-nix - <br> </h1>
    <h3> or <i>How my dotfiles escalated into a multi-platform configuration system for declaratively-configured world domination</i> (working title).</h3>
</div>

<div style="display: flex; align-items: center; padding: 8px 12px; border-radius: 8px; font-size: 1.6em;">
    <span>
        Make-nix is a 
        <img src="assets/gnu-invert.png" alt="GNU" width="25" style="vertical-align: middle; margin: 0 0px;">
        make controlled
        <img src="assets/nix.png" alt="NixOS" width="32" style="vertical-align: middle; margin: 0 0px;">
        NixOS
        <img src="assets/nix-darwin.png" alt="Nix Darwin" width="30" style="vertical-align: middle; margin: 0 0px;">
        Nix-Darwin and
        <img src="assets/home-manager_bottom.png" alt="Home Manager" width="90" style="vertical-align: middle; margin: 0 0px;">
        configuration management script.
    </span>
</div>

## About
In 2023 I started experimenting with Nix. I thought I could keep it contained to just some 
of my side-projects, but I soon lost control. I had heard about Nix before, but no one ever warned me;
A little Nix on the side quickly became NixOS on my personal computer. In no time, I found myself up
late at nights re-writing my dotfiles, trying to make them more declarative, refactoring my system configuration
in a language I can still barely comprehend. But it wasn't enough. I needed more.

At work the hours dragged on while I suffered on Nixless machines. Just the thought of going eight hours without
re-writing a configuration file into a declarative module with type-checking made me break into a cold sweat.
I needed to find a way to feed my addiction. But there were so many systems out there without Nix, how could
I get my fix? How could I continue to experience the un-paralleled high that only comes from gloriously reproducible software?

That pursuit may never end, but for now it has take the form of Make-nix.
## Getting Started

### How does it work?

Make-nix bridges imperative setup decisions — who you are, what machine you are on, what
options you want — with a declarative Nix flake configuration. When you run a make target,
the Makefile collects your parameters and option flags, writes them into a Nix attribute
set file (`make-attrs/system/<user>@<host>.nix` or `make-attrs/home-alone/<user>@<host>.nix`),
and commits that file to git so Nix can read it cleanly. The flake imports this attribute
set and uses it to customise your NixOS, Nix-Darwin, or Home Manager configuration at
build time.

On subsequent runs, make-nix reads the existing attribute file and updates only the values
you have explicitly overridden, preserving everything else. This means you can run
`make switch` with no arguments and it will rebuild exactly the same configuration as
before, or pass new flags to change specific options without specifying everything from
scratch.

---

## Makefile Documentation

<details>
<summary>📘 <strong>make-nix usage</strong></summary>

### **Usage**

```sh
make <help|install|check|build|switch|all>
     [TGT_USER=<user>]
     [TGT_HOST=<host>]
     [TGT_SYSTEM=<system>]
     [CFG_TAGS=<tag1>,<tag2>,...]
     [SPECS=<spc1>,<spc2>,...]
     [OPTION FLAGS]
```

---

### **Make Targets**

| Target    | Description                                                                          |
| --------- | ------------------------------------------------------------------------------------ |
| `help`    | View make-nix usage help.                                                            |
| `install` | Install Nix and/or Nix-Darwin on a bare MacOS or Linux system. Does not run on NixOS or Nix-Darwin managed systems. |
| `check`   | Validate flake configurations for the target user and host.                          |
| `build`   | Build Nix closures for home and system configurations. Runs `check` first to prevent configuration mismatches. |
| `switch`  | Check, build, and activate configurations.                                           |
| `all`     | Full pipeline: install through switch for a bare system.                             |

#### Sub-targets

| Target          | Description                                              |
| --------------- | -------------------------------------------------------- |
| `check-home`   | Validate only the Home Manager flake configuration.      |
| `check-system` | Validate only the system (NixOS or Nix-Darwin) flake configuration. |
| `build-home`   | Build only the Home Manager configuration closure.       |
| `build-system` | Build only the system configuration closure.             |
| `switch-home`  | Check, build, and activate only the Home Manager configuration. |
| `switch-system`| Check, build, and activate only the system configuration. |

---

### **Configuration Parameters**

All parameters are autodetected from the current system if not supplied. Override
them to build configurations for a different user, host, or architecture than the
one you are currently running on.

| Variable     | Description                                                                                                                                                |
| ------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `TGT_USER`   | Target username. Defaults to the current user.                                                                                                             |
| `TGT_HOST`   | Target hostname. Defaults to the current hostname.                                                                                                         |
| `TGT_SYSTEM` | Target system tuple. Defaults to the current platform. Valid values: `x86_64-linux`, `aarch64-linux`, `x86_64-darwin`, `aarch64-darwin`.                  |
| `CFG_TAGS`   | Comma-separated tags to customise the Home Manager configuration at build time (no spaces). Example: `CFG_TAGS=server,minimal`                             |
| `SPECS`      | Comma-separated list of NixOS specialisation configurations to build (no spaces). Example: `SPECS=egpu,powersave`                                          |

---

### **Option Flags**

These are **boolean**. Assigning any truthy value enables the flag; assigning any
falsey value explicitly disables it.

> **Truthy values:** `1`, `y`, `Y`, `yes`, `Yes`, `YES`, `on`, `On`, `ON`, `true`, `True`, `TRUE`
> **Falsey values:** `0`, `n`, `N`, `no`, `No`, `NO`, `off`, `Off`, `OFF`, `false`, `False`, `FALSE`

#### **Install Flags** (`install` | `all`)

| Flag               | Description                                                                                                                         |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------------------- |
| `USE_DETERMINATE`  | Install Nix using the Determinate Systems installer. Default is the official NixOS installer.                                      |
| `INSTALL_DARWIN`   | Install Nix-Darwin for MacOS.                                                                                                       |
| `USE_HOMEBREW`     | Install Homebrew (MacOS only).                                                                                                      |
| `SINGLE_USER`      | Install Nix in single-user mode. Only supported with the default installer.                                                         |
| `USE_CACHE`        | Use additional binary cache substituters defined in `make.env` as `NIX_CACHE_URLS` (comma-separated URLs, no spaces).              |
| `USE_KEYS`         | Trust additional public keys defined in `make.env` as `TRUSTED_PUBLIC_KEYS` (comma-separated key pairs).                           |

#### **Configuration Flags** (`check` | `build` | `switch` | `all`)

| Flag           | Description                                                                                                               |
| -------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `DRY_RUN`      | Evaluate the configuration without building or activating it. Passes `--dry-run` to Nix. No outputs will be produced.   |
| `HOME_ALONE`   | Configure for a system running Home Manager without NixOS or Nix-Darwin. Autodetected from the current system if not set. |
| `USE_HOMEBREW` | Enable Homebrew package options in a Nix-Darwin configuration.                                                            |
| `USE_CACHE`    | Use additional binary cache substituters (see install flags above).                                                       |
| `USE_KEYS`     | Trust additional public keys (see install flags above).                                                                   |

#### **Universal Flags** (any target)

| Flag        | Description                                                                              |
| ----------- | ---------------------------------------------------------------------------------------- |
| `KEEP_LOGS` | Preserve logs after operations instead of cleaning up. Log paths are printed at startup. |

---

### **Usage Examples**

```sh
# Install Nix using the default installer in single-user mode:
make install SINGLE_USER=true

# Install Nix using the Determinate Systems installer with Nix-Darwin on MacOS:
make install USE_DETERMINATE=true INSTALL_DARWIN=true

# Validate flake configurations for the current user and host:
make check

# Validate only the Home Manager configuration for the current user:
make check-home

# Build and activate the Home Manager configuration on a standalone system:
make switch-home HOME_ALONE=true

# Build and activate the current system configuration; autodetect all settings:
make switch-system

# Build and activate the Home Manager configuration for user sam on host xps-15,
# with tags 'debian' and 'server', targeting aarch64-linux:
make switch-home TGT_USER=sam TGT_HOST=xps-15 \
  TGT_SYSTEM=aarch64-linux CFG_TAGS=debian,server HOME_ALONE=true

# Dry-run evaluation of both system and home configurations:
make switch DRY_RUN=true

# Full bootstrap of a bare system — install Nix and activate all configurations:
make all
```

</details>
```
