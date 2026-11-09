# Pixel VR Player plugins

Plugins add connections to [Pixel VR Player](https://github.com/Pixelplanet/Pixel-VR-Player): devices,
other apps, services. This repository is the player's built-in plugin source: the player reads
`index.json` and offers what is listed here under **Settings > Plugins**.

## Installing

In the player open **Settings > Plugins**. Plugins from this repository appear as
**Install ...** lines, newer versions as **Update ...**. A new plugin starts switched off; turn it on
with its switch. Every download is checked against the checksum in `index.json` before it is installed.

You can also install a `.pvrplugin` file by hand: put it into your **Downloads** folder (or a folder
inside it) and it appears on the same page.

## Plugins

| Plugin | What it does |
|---|---|
| **Funscript devices** | Plays the `.funscript` next to a video on devices connected to [Intiface Central](https://intiface.com/central/). Finds Intiface on your network. |
| **Sync with MultiFunPlayer / XBVR (DeoVR protocol)** | Lets MultiFunPlayer, ScriptPlayer, FunFlixDroid or XBVR follow the video playing in Pixel VR Player, as they would follow DeoVR. Only needed if one of those apps controls your devices. |

## Requesting a plugin

Open an issue with the **Plugin request** template: what it should connect to and what it should do.

## Writing a plugin

Plugins are separate programs that talk to the player over stdin / stdout (JSON lines). The SDK, an
example plugin and the packaging script are in the player repository (`plugins/`). To have a plugin
listed here, open a pull request that adds the package to `packages/` and an entry to `index.json`
(id, name, version, description, url, sha256, size). Every plugin is reviewed before it is listed:
plugins run as programs on the headset, so only reviewed, open-source plugins are accepted.

## Safety

Plugins only get what they ask for in their `plugin.json` (permissions are shown in the player), they
never see videos from the private vault unless you allow it, and the player stops them when you
switch them off.
