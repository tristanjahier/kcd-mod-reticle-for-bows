# Reticle for bows - A mod for Kingdom Come Deliverance

## Installation

Extract and copy the mod directory (`reticle_for_bows`) inside the game's Mods\ directory.

That's it.

## Development

On Windows, use Powershell to run these scripts:

```powershell
.\build.ps1
```
=> Creates the .pak, and put everything together in the dist\ directory. This is what you can deploy or publish.

```powershell
.\deploy.ps1
```
=> Runs the build script, then copy the mod files to the game's Mods\ directory, and add an entry to `mod_order.txt` if needed.
