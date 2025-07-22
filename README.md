# Pete3n's Dotfiles Flake
- A NixOS, Nix-Darwin, and Home-manager configuration repo.

## Makefile documentation
To view the Makefile documentation in your terminal, run:
```
make
```
or

```
make usage
```

<details>
<summary>📘 <strong>Usage</strong></summary>

---

**make** `<home|system|all|test>` [`host=<host>`] [`user=<user>`] [`system=<system>`] `[option variables]`

#### 💡 Option Variables:

- `DRY_RUN=1` – *Evaluate the target but do not build or switch the configuration.*
- `EGPU=1` – *Build the eGPU host specialisation.*
- `WAYLAND=1` – *Build the Wayland host specialisation.*
- `X11=1` – *Build the X11 host specialisation.*
- `BOOT_SPECIAL=1` – *Set the default boot menu option to the built specialisation.*

</details>

<details>
<summary>🧪 <strong>Examples</strong></summary>

---
- Switch the home-manager configuration for current user; autodetect system type:
  ```sh
  make home
  ```

- Switch the home-manager configuration for user joe; autodetect system type:
  ```sh
  make home user=joe
  ```

- Switch the home-manager configuration for user sam; target an aarch64-darwin platform:
  ```sh
  make home user=sam system=aarch64-darwin
  ```

- Rebuild and switch the current system's configuration; autodetect hostname and system platform:
  ```sh
  make system
  ```

- Rebuild and switch the system configuration for host workstation1; target an aarch64-linux platform:
  ```sh
  make system host=workstation1 system=aarch64-linux
  ```

- Rebuild and switch the current system's configuration and current user's home-manager configuration;  
  autodetect all settings:
  ```sh
  make all
  ```

- Evaluate the current system's configuration and current user's home-manager config;  
  autodetect all settings:
  ```sh
  make all DRY_RUN=1
  ```

- Rebuild and switch the current system's configuration and current user's home-manager configuration;  
  autodetect all settings:
  ```sh
  make all WAYLAND=1 BOOT_SPECIAL=1
  ```

- Rebuild and switch the system configuration for host workstation1, and home-manager configuration for user joe;  
  target an x86_64-linux platform:
  ```sh
  make all host=workstation1 system=x86_64-linux user=joe
  ```

- Run 'nix flake check' for all system and home-manager configurations:
  ```sh
  make test
  ```
</details>
