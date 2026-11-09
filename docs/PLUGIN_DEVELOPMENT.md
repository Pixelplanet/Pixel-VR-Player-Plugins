# Writing plugins for Pixel VR Player (plugin API 1)

A plugin is a **separate program** that Pixel VR Player starts and talks to over **stdin / stdout,
one JSON object per line**. It can be written in any language that runs on the headset (SteamOS,
arm64 Linux). This kit uses C++17 with a single-header SDK, but a Python script works just as well.

- `dev/sdk/pvr_plugin.hpp`: C++ SDK (message loop, media clock, helpers) + `mini_json.hpp`
- `dev/example/`: a complete example plugin (not offered to users) and `build.sh`
- `dev/tools/package-plugin.sh`: packs a built plugin into a `.pvrplugin`

## 1. Quick start

```sh
sh dev/example/build.sh                                        # on the headset or any arm64 Linux
sh dev/tools/package-plugin.sh dev/example/build/example .     # -> org.pixelvr.example-0.2.0.pvrplugin
```
Copy the `.pvrplugin` into `~/Downloads` on the headset, open **Settings > Plugins** in the player,
press **Install ...**, then switch the plugin on. Its log is `~/.cache/pixelvr/plugins/<id>.log`
(everything the plugin writes to stderr).

## 2. What a plugin can and cannot do

**Can:**
- Follow playback on every screen: which file is open, its duration, format and projection, play /
  pause / seek / buffering / scrubbing, with an exact clock to stay in sync (section 6).
- Read small files that sit **next to the video** and match the patterns it declares (e.g.
  `{base}.funscript`), also on SMB / SFTP / WebDAV shares, without ever seeing credentials.
- Play, pause and seek the video (permission `control`).
- Show things in the player: a status line, short messages, a live gauge above the control panel, an
  intensity graph on the timeline, and its own settings page (toggles, choices, text fields, buttons).
- Open its own network connections and ports (devices, home automation, web APIs, ...), and keep files in
  its own data folder.

**Cannot:**
- See passwords, share credentials, Plex / Jellyfin tokens, browser cookies or URLs from the browser
  screens (web screens are reported only as "web").
- See anything about **vault** (private) videos: they arrive as `private: true` without name or files,
  unless the user turns on "Use with vault videos" for that plugin while the vault is unlocked.
- Read arbitrary files through the player, open files on screens, change the playback speed, draw
  freely in VR or capture the picture or sound.
- Keep running when the user switches it off, or block the player: it runs as its own process and is
  stopped, restarted after crashes (up to 3 times) or killed when it misbehaves.

Plugins are ordinary programs with the user's rights on the headset. That is why the plugin
repository only lists reviewed, open-source plugins, and why the user sees each plugin's permissions.

## 3. Files and lifecycle

| What | Where |
|---|---|
| Installed plugin (manifest + files) | `~/.local/share/pixelvr/plugins/<id>/` |
| Plugin data (writable, kept across updates) | `~/.local/share/pixelvr/plugin-data/<id>/` |
| Log (stderr) | `~/.cache/pixelvr/plugins/<id>.log` |
| Enabled state, setting values | `~/.config/pixelvr/plugins.json` (owned by the player) |

Environment: `PIXELVR_PLUGIN_API=1`, `PIXELVR_PLUGIN_ID`, `PIXELVR_PLUGIN_DIR`, `PIXELVR_PLUGIN_DATA`.
The working directory is the plugin folder.

1. The player starts enabled plugins and sends `hello`. **Answer `hello` within 5 seconds**, or the
   plugin is stopped as "not responding".
2. Events arrive as they happen (section 5).
3. On `shutdown`, on end of stdin and on SIGTERM: **stop all outputs (devices!) and exit.** The player
   waits about 2 s, then sends SIGTERM, then SIGKILL.
4. A crashing plugin is restarted up to 3 times, then shown as stopped.

## 4. The manifest (`plugin.json`)

```json
{
  "id": "org.example.myplugin",
  "name": "My plugin",
  "version": "1.0.0",
  "api": 1,
  "description": "One sentence: what it does for the user.",
  "author": "Your name",
  "homepage": "https://github.com/you/myplugin",
  "license": "MIT",
  "exec": ["myplugin"],
  "permissions": ["playback", "ui"],
  "sidecars": ["{base}.txt"],
  "settings": [
    { "key": "server", "type": "text",      "label": "Server address", "default": "192.168.1.10" },
    { "key": "on",     "type": "toggle",    "label": "Do the thing",   "default": true },
    { "key": "level",  "type": "choice",    "label": "Strength", "options": ["Low", "Mid", "High"], "default": 1 },
    { "key": "mode",   "type": "segmented", "label": "Mode", "options": ["A", "B"], "default": 0 },
    { "key": "test",   "type": "action",    "label": "Send a test" }
  ]
}
```
- `id`: reverse-domain, unique, never changes (updates are matched by id; versions compare as dotted
  numbers).
- `exec`: the program and its arguments; `exec[0]` is looked up in the plugin folder first, then in
  `PATH` (e.g. `["python3", "main.py"]`).
- `sidecars`: patterns for `files.read`; `{base}` is the video's name without extension. Only ordinary files count: links
  next to the video are never offered or read.
- Settings appear on the plugin's page in this order. Values arrive in `hello` and `settings`:
  toggles as `true` / `false`, choices and segmented as the option index, text as a string. An
  `action` is a button; pressing it sends `action` with its key.

## 5. Messages

Every line is one JSON object with a `"type"`. **Ignore unknown types and fields**: new ones are
added without changing the API number. Lines can be up to 1 MiB.

### 5.1 Player -> plugin

| type | fields | when |
|---|---|---|
| `hello` | `api`, `apiMinor`, `app`, `granted` [permissions], `settings` {key: value} | first line |
| `screens` | `screens`: [{`screen`, `kind` (video / web / empty), `selected`, `audio`}] | after hello and on every change |
| `media.open` | `screen`, `media` (id), `private`, `fileName`, `title`, `source` (local / smb / sftp / webdav / plex / jellyfin / http), `duration` (s), `projection` (flat / 180 / 360), `stereo` (mono / sbs / tb), `sidecars` [names] | a file opened on a screen |
| `media.state` | `screen`, `media`, `playing`, `buffering`, `scrubbing`, `position` (s), `rate`, `clock` (ms), `reason` (play / pause / seek / rate / buffer / scrub / tick) | at once on every change, and every 250 ms while playing |
| `media.sidecars` | `screen`, `media`, `sidecars` [names you may read] | the folder listing finished (often after `media.open`) |
| `media.close` | `screen`, `media`, `reason` | a file closed |
| `app.state` | `focused`, `worn`, `exiting` | the user took the headset off, opened the system menu, ... |
| `settings` | `settings` {key: value} | the user changed a setting |
| `action` | `action` (setting key) | the user pressed a button setting |
| `result` | `id`, `ok`, `data` or `error` | answer to a request with an `id` |
| `shutdown` | | stop now |

`media.state` with `scrubbing: true` means the user drags the timeline or holds the scrub stick:
outputs that follow the video should pause until it is false again. `focused: false` or
`worn: false` in `app.state` should stop devices at once.

### 5.2 Plugin -> player

| type | fields | permission | notes |
|---|---|---|---|
| `hello` | `api`, `name`, `version` | | reply to the player's hello |
| `status` | `text`, `level` (ok / warn / error) | | the plugin's line in the Plugins list and on its page, e.g. "Connected, 2 devices" |
| `notice` | `text` | `ui` | a short message for the user (on the plugin page or above the control panel); at most one per 3 s |
| `log` | `level`, `text` | | into the plugin log (stderr works too) |
| `ui.settings` | `settings` [definitions as in the manifest] | `ui` | replaces the settings list (e.g. to fill a device choice) |
| `settings.set` | `key`, `value` | | saves one of the plugin's own **text** settings (e.g. an address it found) |
| `ui.gauge` | `id`, `label`, `value` (0..1, or < 0 to hide) | `ui` | a small live meter above the control panel, up to ~30 updates/s |
| `ui.timeline` | `screen`, `media`, `tracks`: [{`id`, `label`, `segments`: [[startMs, endMs, heat 0..1], ...]}] | `ui` | an intensity graph above the timeline (bars or line, the user's choice); `[]` clears it |
| `control` | `id`, `screen`, `media`, `do` (play / pause / seek), `position` (s) | `control` | anything else is answered "unsupported" |
| `files.read` | `id`, `screen`, `media`, `name` | `files.sidecar` | returns `{name, text}` (UTF-8) or `{name, base64}`, max 16 MiB; only names from `media.sidecars` |

## 6. Staying in sync: the clock

Player and plugin run on the same machine. `media.state` carries `position` (seconds, the frame
being shown) and `clock` (milliseconds of `CLOCK_MONOTONIC` when it was sampled). The current
position is

```
now = position + (monotonic_ms() - clock) / 1000 * rate      while playing && !buffering
```

so a plugin can drive outputs smoothly between the 250 ms ticks. The C++ SDK does this in
`MediaClock::now()`. Add a user-adjustable offset for device latency.

Which screen to follow: the **selected** screen (`selected: true` in `screens`); the SDK's
`Screens::focus()` returns it. Users switch screens by selecting another one.

## 7. Permissions

| Permission | Grants |
|---|---|
| `playback` | `screens` and `media.*` events with file name, title, source, duration and format |
| `playback.path` | also the full path or network address (credentials always removed) |
| `control` | `control` requests (play / pause / seek) |
| `files.sidecar` | `files.read` for the declared `sidecars` patterns |
| `ui` | `notice`, `ui.*` |
| `network` | informs the user that the plugin opens network connections or ports (not enforced) |

Ask only for what you use; the user sees the list before switching a plugin on.

## 8. Testing without the hardware

Build the thing a plugin talks to as a small fake: the first-party plugins are tested against a fake
Intiface server with a live web page of virtual devices, and a fake sync-app client. A plugin is just
a program reading stdin: a test script can start it, send `hello` / `screens` / `media.*` lines and
check what it answers, without the player.

## 9. Publishing in the plugin repository

1. Put the source in a public repository with an open-source licence.
2. Open a pull request here that adds `packages/<id>-<version>.pvrplugin` and an entry in
   `index.json` (`id`, `name`, `version`, `description`, `url` = the raw GitHub address of the
   package, `sha256`, `size`, `minApp`) and the texts users see:
   - `summary`: one line on the Install plugins list
   - `about`: what it does, in plain words (paragraphs)
   - `howto`: what the user has to do to use it (short steps)
   - `changelog`: `{"1.1.0": ["what changed", ...], ...}`, shown when the user updates
   Keep `about` + `howto` short: the details page shows about 10 lines.
3. After review it appears for every user under Settings > Plugins; a higher `version` shows as an
   update.
