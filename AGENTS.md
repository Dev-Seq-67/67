# Repository Guidelines

## Project Structure & Module Organization

- `src/67`: POSIX launcher; resolves assets independently of the working directory and opens a private Zsh session.
- `src/prompt.zsh`: private Zsh configuration and module loading.
- `src/prompt/`: ANSI decoding (`ansi.zsh`), frame cache (`frames.zsh`), renderer lifecycle (`renderer.zsh`), and ZLE integration (`editor.zsh`).
- `docs/architecture.md`: data flow, state ownership, and lifecycle constraints for maintainers.
- `assets/67.gif`: shipped animation; `design/` contains source artwork, previews, and design notes.
- `install.sh` / `uninstall.sh`: installation under `/usr/local`; support `DESTDIR` for staging.
- `packaging/`: Debian metadata and build script. Generated packages live in `dist/`.
- `packaging/apt/`: dedicated signing key initialization, signed APT repository generation, and publication preparation. Private signing material stays outside this repository.
- `apt/`: public, signed repository snapshot published by `.github/workflows/publish-apt.yml` on GitHub Pages.
- `tests/`: shell test runners, Perl capture/measurement helpers, and recorded results.

## Build, Test, and Development Commands

- `./src/67`: run locally in an interactive terminal; requires Chafa and Zsh.
- `./packaging/build-deb.sh`: build the package using `dpkg-deb`; version comes from `packaging/control`.
- `./packaging/apt/prepare-publication.sh`: rebuild, sign, verify, and copy public APT files to `apt/`. Requires the key created by `./packaging/apt/init-key.sh`, GnuPG, and `apt-utils`.
- `./tests/apt-repository.sh`: verify repository signatures and downloads with isolated APT state, including tampering controls; installs nothing.
- `./tests/regression.sh`: verify command colors, including a deliberately broken temporary copy.
- `./tests/integration.sh`: check animation, input, job control, Ctrl+C, and cleanup using isolated tmux sessions.
- `./tests/resources.sh`: measure Linux CPU, RSS, threads, and descriptors; requires Perl and tmux.
- `sh -n src/67 install.sh uninstall.sh packaging/build-deb.sh tests/*.sh`: POSIX syntax checks. Run `zsh -n` separately on `src/prompt.zsh` and each `src/prompt/*.zsh` module; Zsh only checks the first script passed to it.

Use `stage=$(mktemp -d)` followed by `DESTDIR="$stage" ./install.sh` and `DESTDIR="$stage" ./uninstall.sh` for safe installation checks.

## Coding Style & Naming Conventions

Use four-space indentation. Keep launch/install/build scripts POSIX-compatible; reserve Zsh features for `prompt.zsh`. Prefix internal Zsh state and functions with `_67_`. Quote paths, preserve executable permissions, and comment lifecycle constraints rather than obvious operations. No formatter or dedicated linter is configured. Avoid adding runtime dependencies.

## Testing Guidelines

Tests use shell, tmux, and Perl rather than a framework. Use descriptive `.sh` runner and `.pl` helper names. Add regression checks for behavior changes when testing is requested; there is no coverage percentage target. Record measurement conditions and distinguish partial checks from complete passes. The resource suite currently has a documented resize failure; consult `tests/results/README.md` before claiming it passes.

## Commit & Pull Request Guidelines

This snapshot has no usable Git history, so no existing commit convention can be established. Prefer concise imperative subjects describing one logical change. PR descriptions should explain behavior changes, tests performed, known limitations, and relevant issues. Include terminal captures for visual changes. Keep package versions and README installation examples synchronized.

## Terminal & Configuration Invariants

Never modify user dotfiles or the default shell. Sprite glyphs must never enter executed input. Preserve user background jobs and `$!`; clean up only the renderer owned by the session. Clear `region_highlight` before removing its display to prevent colors leaking onto accepted commands.
