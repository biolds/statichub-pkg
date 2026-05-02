# em-dosbox

Installs the upstream Em-DOSBox browser runtime. By default, it runs a working empty DOSBox environment. When provided with user data, it launches a generated page that runs your configured DOS program directly.

## Providing DOS Programs

Place your DOS application data (program files, assets, etc.) in:

~/.local/share/statichub/data/emu/em-dosbox/

Add a `statichub.json` configuration file in the root of this directory to specify the program to launch.

### statichub.json Format

Example:

{
"executable": "PRINCE/PRINCE.EXE",
"args": ["LEVEL1"]
}

- `executable` (required): Relative path to a `.EXE`, `.COM`, or `.BAT` file under the data directory.
- `args` (optional): Array of strings passed as command-line arguments to the executable.

For more details about data directories, see the [statichub-cli documentation](https://github.com/biolds/statichub-cli/).

## Updating Bundled Data

After modifying the contents of `~/.local/share/statichub/data/emu/em-dosbox/`, re-run the install command to update the static build bundled with the package:

statichub install emu/em-dosbox
