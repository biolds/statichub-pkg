# doom-wasm

This package ships two distinct kinds of content with different licensing terms:

- Code: the `doom-wasm` engine and build artifacts are distributed under `GPL-2.0`, following the upstream project.
- Data: the bundled `doom1.wad` file is the original Doom shareware episode data and remains distributed under the Doom shareware license, not under the GPL. Source: https://doomwiki.org/wiki/DOOM1.WAD

## Providing Custom WAD Files

Place your custom WAD file (e.g., a full version `doom.wad`) in:

~/.local/share/statichub/data/games/doom-wasm/doom.wad

The file must be named `doom.wad`. It will replace the default shareware `doom1.wad` when the package is installed.

For more details about data directories, see the [statichub-cli documentation](https://github.com/biolds/statichub-cli/).

## Updating Bundled Data

After adding or modifying the WAD file in `~/.local/share/statichub/data/games/doom-wasm/`, re-run the install command to update the static build bundled with the package:

statichub install games/doom-wasm
