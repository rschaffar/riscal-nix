# riscal-nix

An unofficial Nix flake for **RISCAL 4.3.7**, the RISC Algorithm Language.
Run the desktop application without manually installing Java, JavaFX, SWT or
solver binaries.

[RISCAL](https://www3.risc.jku.at/research/formal/software/RISCAL/) is developed
at the Research Institute for Symbolic Computation, Johannes Kepler University
Linz. Its main author and bug-report contact is Wolfgang Schreiner. This
repository provides independent Nix packaging, not an upstream RISCAL release.

## Run

Requires Nix with the `nix-command` and `flakes` features enabled, on
**x86_64 Linux**, with a graphical session providing X11 or Xwayland. NixOS is
the tested host environment; macOS and ARM are not supported by this package.
There is no need to install Java globally, enter a container or rebuild NixOS.

From a local checkout:

```sh
nix run
```

After this repository has been published as `rschaffar/riscal-nix`, the same app
will be available without cloning:

```sh
nix run github:rschaffar/riscal-nix
```

**The GitHub URL is the intended publication location, not a currently verified
published repository.** The first run fetches dependencies and may compile the
application. Nix does not remove the need for working network/DNS access.

Pass an exercise filename or other upstream arguments after `--`:

```sh
nix run . -- "path/to/course exercise.txt"
```

The default and named `.#riscal` apps are identical. The launcher preserves the
caller's working directory and filenames containing spaces. Diagnostics remain
visible on stderr. RISCAL settings remain mutable Java Preferences in your home.

For reproducibility, keep this flake's `flake.lock`; consumers pin the repository
revision in their own lock file. After publication, an explicit revision can also
be run as `nix run github:rschaffar/riscal-nix/<commit>`.

## Install or use in another flake

To add the command and desktop entry to your Nix profile from a local checkout:

```sh
nix profile install .#riscal
```

Alternatively add the published repository as an input to your own flake:

```nix
inputs.riscal.url = "github:rschaffar/riscal-nix";
```

Then use its package in a NixOS or Home Manager module where `inputs` is in
scope (for example, passed through `specialArgs`/`extraSpecialArgs`):

```nix
{ pkgs, inputs, ... }:
{
  # Use home.packages instead for a Home Manager module.
  environment.systemPackages = [
    inputs.riscal.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
```

An `overlays.default` output is also provided, exposing `pkgs.riscal`. Using the
overlay, or making this flake's nixpkgs input follow another input, changes the
dependency set; rerun the checks with that package set. The pinned package output
is the simplest way to reuse exactly the dependencies tested by this project.
No NixOS module or host configuration is required.

## Examples and manual

Build a package link to access the examples and offline PDF:

```sh
nix build
cp -n result/share/riscal/spec/gcd.txt ./gcd.txt
nix run . -- ./gcd.txt
```

The package contains:

- `bin/riscal` and the equivalent `bin/RISCAL`;
- the application-menu entry **RISCAL**;
- `share/riscal/spec/`: example specifications;
- `share/riscal/doc/main.pdf`: the offline manual;
- `share/riscal/README`, `CHANGES`, and `COPYING`: upstream documentation.

Files inside the Nix store are read-only. Copy an example before editing it, or
use **Save As**. The app does not take over the file association for all `.txt`
files. **Help → Online Manual** uses the upstream HTTPS site and needs network
access; the PDF does not.

## Packaging choices

- The official versioned release archive is pinned by SHA-256. It includes the
  Java source and a matching set of third-party jars and solver executables.
  The moving SVN development tree is not used. An unreleased fix would require
  a reviewed, exact SVN revision and content hash, not an unpinned checkout.
- RISCAL's Java sources are rebuilt using OpenJDK 21 with integrated JavaFX.
  The OpenJFX SWT bridge and bundled GEF/Zest dependencies enable visualization.
- Matching SWT JNI libraries are extracted and patched for NixOS, then removed
  from the jar so unpatched copies cannot be extracted at runtime. GTK3 and
  WebKitGTK 4.1 are included; the unused GTK4 native library is excluded.
- Upstream's tested solver versions are retained: Boolector 3.1.0, CVC4 1.7,
  cvc5 1.1.2, Vampire 4.7, Yices 2.6.1, and Z3 4.13.0. Their executables are on
  RISCAL's private PATH, not installed as global solver commands.
- A source fix makes legacy SMT solver discovery use PATH for its default `.`
  directory. Explicitly selected solver directories still work. No versioned
  store directory is persisted as the default, and the launcher never changes
  into the read-only store.
- Upstream's `SWT_GTK3=1`, `GDK_BACKEND=x11`, and
  `WEBKIT_DISABLE_COMPOSITING_MODE=1` workarounds apply only to this application.
  No system-wide graphics settings are changed, and WebKit's sandbox is not
  disabled in the normal application.
- Java starts with a 256 MiB heap, up to 2 GiB, and a 64 MiB thread stack.

The flake contains no private caches, extra cache trust settings, personal
configuration or dependency on another local checkout.

## Development and verification

```sh
nix fmt
nix flake check -L
nix build --no-link
```

The checks cover default/named package and app wiring, overlay equivalence, GCD
execution with a filename containing spaces, all six solver version commands,
a theorem through four legacy SMT solvers, and a visible real SWT application
window. A further check creates a JavaFX/GEF SWT scene and renders local
HTML/JavaScript in SWT's WebKit browser.

GUI checks use Xvfb and software JavaFX rendering. Only the isolated local-HTML
test disables WebKit's nested sandbox, because that cannot run inside the Nix
build sandbox. This setting is never added to the application launcher. The
checks do not establish physical GPU behavior, interactive visualization,
online-manual navigation, every theorem-proving mode, or non-NixOS host support.

To update, review upstream's
[README](https://www3.risc.jku.at/research/formal/software/RISCAL/README) and
[CHANGES](https://www3.risc.jku.at/research/formal/software/RISCAL/CHANGES).
Update `version` and `src.hash` together in `pkgs/riscal/package.nix`. Recheck
Java/JavaFX/SWT requirements, solver versions, source substitutions and native
dependencies. Never substitute a mutable `latest` URL. Update nixpkgs separately
with `nix flake update nixpkgs`, inspect `flake.lock`, and rerun the checks.
Repeat interactive acceptance on the intended desktop before deployment.

## Licenses

This repository's Nix packaging, tests and documentation are **MIT licensed**;
see [LICENSE](LICENSE). **RISCAL itself, including its Java code modified during
the build, remains GPL-3.0-or-later.** Its bundled third-party components retain
their respective upstream licenses. The packaging license does not relicense
the application or its dependencies. The official archive includes RISCAL's
source and `COPYING`; those terms and applicable third-party source obligations
still apply when redistributing built binaries.
