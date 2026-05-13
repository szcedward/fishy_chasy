# my-first-game

A Roblox/Luau game scaffold designed for the **Cursor + Rojo + Studio** workflow.

- Code lives in `src/` and is edited in Cursor.
- [Rojo](https://rojo.space/) syncs the file tree into Roblox Studio in real time.
- [Rokit](https://github.com/rojo-rbx/rokit) pins the Rojo + StyLua versions in `rokit.toml`.
- [Luau LSP](https://marketplace.visualstudio.com/items?itemName=JohnnyMorganz.luau-lsp) gives autocomplete, type-checking, and Roblox API hints inside Cursor.

## Project layout

```
.
├── default.project.json     # Rojo project mapping (filesystem -> DataModel)
├── rokit.toml               # Pinned versions of Rojo + StyLua
├── stylua.toml              # Formatter config (tabs, 120 cols, double quotes)
├── setup.ps1                # One-shot installer (run once on a new machine)
├── .vscode/
│   ├── settings.json        # Cursor / Luau LSP / StyLua settings
│   └── extensions.json      # Recommended extensions (Cursor will prompt)
└── src/
    ├── server/              # -> ServerScriptService.Server
    │   └── Hello.server.luau
    ├── client/              # -> StarterPlayer.StarterPlayerScripts.Client
    │   └── Hello.client.luau
    └── shared/              # -> ReplicatedStorage.Shared
        └── Greeter.luau
```

File-extension conventions (Rojo):

| extension          | Roblox instance | example                  |
| ------------------ | --------------- | ------------------------ |
| `.server.luau`     | `Script`        | `Hello.server.luau`      |
| `.client.luau`     | `LocalScript`   | `Hello.client.luau`      |
| `.luau`            | `ModuleScript`  | `Greeter.luau`           |
| `init.server.luau` | folder -> Script in place of the folder | (not used here) |

## First-time setup (do this once)

### 1. Install Roblox Studio

Download from [roblox.com/create](https://www.roblox.com/create) -> "Start Creating".
Sign in (or register) with a Roblox account, then open Studio at least once so it finishes
its post-install bootstrap.

### 2. Run the installer script

Open a terminal in Cursor (`` Ctrl+` ``) at this folder and run:

```powershell
.\setup.ps1
```

If PowerShell blocks the script, allow it for this session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\setup.ps1
```

The script installs Rokit, downloads Rojo + StyLua at the pinned versions, and
drops the Rojo plugin into Roblox Studio.

> If the Rokit installer succeeds but reports `'rokit' is still not on PATH`,
> close the terminal and open a new one, then re-run `.\setup.ps1`.

### 3. Install Cursor extensions

When you open this folder in Cursor, it should pop up "This workspace has extension
recommendations" -> click **Install All**. If it doesn't, install these manually
from the Extensions panel:

- `evaera.vscode-rojo` - Rojo integration (status bar, start/stop server)
- `JohnnyMorganz.luau-lsp` - Luau language server
- `JohnnyMorganz.stylua` - formatter

### 4. Verify the sync chain

1. In Cursor terminal: `rojo serve` (defaults to `localhost:34872`).
2. In Roblox Studio: **File -> New -> Baseplate**.
3. Toolbar -> **Plugins** -> click the **Rojo** icon -> **Connect**.
   You should see the server tree light up: `ServerScriptService.Server.Hello`,
   `StarterPlayerScripts.Client.Hello`, `ReplicatedStorage.Shared.Greeter`.
4. Click **Play** in Studio. The Output window should print:
   ```
   Hello from Cursor + Rojo! (server)
   Hello, client! (from ReplicatedStorage.Shared.Greeter)
   ```
5. Stop the playtest. In Cursor, edit the print in `src/server/Hello.server.luau`,
   save. The change should appear in Studio's script editor immediately.

If all four steps work, the environment is ready.

## Day-to-day workflow

```powershell
# Start the sync server (leave it running)
rojo serve

# Build a standalone .rbxlx (for sharing or CI)
rojo build -o build/my-first-game.rbxlx

# Format all luau files
stylua src/

# Update Rojo / StyLua to the latest matching minor
rokit update
```

To publish the game: in Studio, **File -> Publish to Roblox** (you keep using
Studio for the 3D world editor and publishing - Cursor only handles code).

## Troubleshooting

- **`rojo: command not found`** after running `setup.ps1`: open a new PowerShell.
  Rokit's bin dir was added to PATH but the current session was started before that.
- **Rojo plugin can't connect** ("connection refused"): make sure `rojo serve` is
  running in your terminal first, then click Connect in Studio.
- **"There are unsaved changes in Studio that don't match the file system"**:
  Studio-side edits are not synced back by default. Either accept Studio's changes
  via the plugin UI, or revert in Studio and edit in Cursor instead.
- **Luau LSP shows `Unknown global 'game'`**: check that `evaera.vscode-rojo` and
  `JohnnyMorganz.luau-lsp` are both installed and that `sourcemap.json` was
  generated (the LSP regenerates it from `default.project.json` on save).

## Reference

- Rojo docs: https://rojo.space/docs/v7
- Luau language: https://luau.org/
- Roblox Creator Hub: https://create.roblox.com/docs
- Rokit: https://github.com/rojo-rbx/rokit
