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

- **Switch the home-manager configuration for the current user** (auto-detect system):
  ```sh
  make home
  ```

- **Switch config for user `joe`**:
  ```sh
  make home user=joe
  ```

- **Switch config for user `sam`, target `aarch64-darwin`**:
  ```sh
  make home user=sam system=aarch64-darwin
  ```

- **Rebuild and switch current system config** (auto-detect hostname/system):
  ```sh
  make system
  ```

- **Rebuild system config for host `workstation1` targeting `aarch64-linux`**:
  ```sh
  make system host=workstation1 system=aarch64-linux
  ```

- **Rebuild system + home-manager config (auto-detect all settings)**:
  ```sh
  make all
  ```

- **Dry run evaluation (no build or switch):**
  ```sh
  make all DRY_RUN=1
  ```

- **Build and boot into Wayland specialisation:**
  ```sh
  make all WAYLAND=1 BOOT_SPECIAL=1
  ```

- **Full target config for user `joe` on `workstation1`:**
  ```sh
  make all host=workstation1 system=x86_64-linux user=joe
  ```

- **Run `nix flake check` for all configurations:**
  ```sh
  make test
  ```

</details>
