# CLAUDE.md — QuestBuddy

## Project Overview

QuestBuddy is a World of Warcraft (WoW) Retail addon written in Lua 5.1. It enables party members to share and monitor each other's quest completion status in real time, with minimal performance overhead. It supports both modern Retail (Dragonflight 12.0+) and legacy (Wrath 11.0+) WoW clients.

---

## Tech Stack

- **Language:** Lua 5.1 (WoW client runtime)
- **Runtime:** World of Warcraft client (no standalone Lua interpreter in prod)
- **Testing:** `luajit` or `lua` via PowerShell test runner (`check.ps1`)
- **Linting:** EmmyLua / Lua Language Server (VSCode extension)
- **Persistence:** WoW SavedVariables (`QuestBuddyDB`)
- **Networking:** WoW addon message API (`RegisterAddonMessagePrefix`, `SendAddonMessage`)

---

## Directory Structure

```
QuestBuddy/
├── QuestBuddy.toc       # Addon manifest (load order, metadata, saved vars)
├── QuestBuddy.lua       # Entry point: slash commands, event wiring, init
├── Compat.lua           # Compatibility layer for API differences across WoW versions
├── PartyApi.lua         # Party member detection and enumeration
├── QuestApi.lua         # Quest log reading and objective parsing
├── Snapshot.lua         # Quest data serialization / deserialization
├── Protocol.lua         # Addon message encoding/decoding, chunking
├── Comms.lua            # Network communication, peer management, timeouts
├── State.lua            # Session state: local snapshot, peer data, focus
├── Tracker.lua          # Buddy tracker overlay frame (watched quests)
├── UI.lua               # Main overview window and quest list frames
├── Options.lua          # Interface Options panel
├── tests/
│   └── test_runner.lua  # Standalone regression test suite
├── check.ps1            # PowerShell script to run tests
└── .vscode/
    └── settings.json    # Lua LS config: WoW globals, Lua 5.1 runtime
```

---

## Module Load Order

Defined in `QuestBuddy.toc`. Modules must be modified with load order in mind:

1. `Compat.lua`
2. `PartyApi.lua`
3. `QuestApi.lua`
4. `Snapshot.lua`
5. `Protocol.lua`
6. `State.lua`
7. `Tracker.lua`
8. `UI.lua`
9. `Options.lua`
10. `Comms.lua`
11. `QuestBuddy.lua`

---

## Running Tests

```powershell
./check.ps1
```

- Requires `lua` or `luajit` on the system PATH.
- Runs `tests/test_runner.lua` which stubs the WoW API and exercises all modules.
- Exit code 0 = pass, non-zero = fail.
- **Always run tests after making changes.**

To run tests directly:
```bash
lua tests/test_runner.lua
# or
luajit tests/test_runner.lua
```

---

## Key Conventions

### Global Namespace

All modules share a single global table `QB` (QuestBuddy). Modules are attached as sub-tables:

```lua
QB = QB or {}
QB.State = {}
QB.Comms = {}
-- etc.
```

Never pollute the global namespace beyond `QB` and `QuestBuddyDB`.

### Event-Driven Architecture

The addon is entirely event-driven. `QuestBuddy.lua` registers WoW frame events and dispatches to module handlers. Key events:

| Event | Handler |
|---|---|
| `ADDON_LOADED` | Initialize saved variables, UI, comms |
| `CHAT_MSG_ADDON` | Route incoming addon messages via `Comms` |
| `QUEST_LOG_UPDATE` | Rebuild local snapshot, broadcast delta |
| `QUEST_WATCH_UPDATE` | Refresh tracker overlay |
| `GROUP_ROSTER_UPDATE` | Detect party joins/leaves, send Hello/Goodbye |
| `ZONE_CHANGED_NEW_AREA` | Trigger snapshot refresh |
| `PLAYER_LOGOUT` | Send Goodbye message to peers |

### Protocol

See `Protocol.lua` and `Comms.lua`. Messages are length-prefixed, binary-safe, and chunked to ≤255 bytes per addon message. Protocol version is `"1"` and prefix is `"QuestBuddy"`.

Message flow:
1. Peer joins party → both sides exchange `Hello`
2. Either side sends `SnapshotRequest`
3. Responder replies with `SnapshotStart` + N×`SnapshotChunk` + `SnapshotEnd`
4. Receiver reassembles and deserializes into peer state
5. Peer leaves party → `Goodbye` sent

### State Management

`State.lua` owns all runtime state. Mutate state only through `State` functions. Key fields:

```lua
QB.State.session = {
    localSnapshot     -- Player's serialized quest data
    localSignature    -- Hash of snapshot (change detection)
    localRevision     -- Monotonic counter
    peers = {
        [name] = {
            snapshot, revision,
            status  -- "Live" | "Updating" | "Stale" | "Offline"
        }
    },
    focusedBuddy      -- Currently displayed buddy name
    simulatedPeerName -- Non-nil when debug simulation is active
}
```

### Saved Variables

`QuestBuddyDB` is the only persisted database. It is initialized with defaults via `QB.Compat:MergeDefaults`. Default structure:

```lua
QB.defaults = {
    options = {
        enableTrackerOverlay    = true,
        showOnlySharedQuests    = false,
        autoFocusSingleBuddy    = true,
        staleTimeoutSeconds     = 90,
        lockWindow              = false,
    },
    window = { point="CENTER", relativePoint="CENTER", x=0, y=0, width=420, height=380 },
    lastFocusedBuddy = nil,
}
```

---

## Slash Commands

| Command | Action |
|---|---|
| `/qb` | Toggle main overview window |
| `/qb refresh` | Request fresh snapshots from all buddies |
| `/qb options` | Open Interface Options panel |

---

## Simulation / Debug Mode

`State.lua` supports a simulated peer for UI development without a live party:

```lua
QB.State:EnableSimulatedBuddy("TestBuddy")  -- activate fake peer
QB.State:DisableSimulatedBuddy()            -- remove fake peer
```

The simulated buddy generates realistic quest objectives and cycles through status states. Check `State.lua` for `simulatedPeerName` and related helpers.

---

## WoW API Usage Notes

- **Quest log:** `C_QuestLog.*` (Retail API). `QuestApi.lua` wraps these.
- **Party:** `GetNumGroupMembers()`, `GetRaidRosterInfo()`. `PartyApi.lua` wraps these.
- **Addon messaging:** `C_ChatInfo.RegisterAddonMessagePrefix`, `SendAddonMessage`. Channel is `"PARTY"`.
- **UI frames:** `CreateFrame`, `BackdropTemplate`, `InterfaceOptions_AddCategory`.
- **Compat layer:** `Compat.lua` polyfills missing APIs for version differences. Add new compatibility shims there.

---

## Adding a New Feature

1. Identify which module owns the responsibility (see module descriptions above).
2. Keep WoW API calls inside `QuestApi.lua` or `PartyApi.lua`; keep protocol logic inside `Protocol.lua`/`Comms.lua`.
3. Add regression tests in `tests/test_runner.lua` for any new serialization, protocol, or state logic.
4. Run `./check.ps1` to confirm tests pass before committing.
5. Update slash commands or options in `QuestBuddy.lua` / `Options.lua` as needed.

---

## Git Branch

Active development branch: `claude/create-claude-docs-L10EP`

Push with:
```bash
git push -u origin claude/create-claude-docs-L10EP
```

---

## Common Pitfalls

- **Lua 5.1 only** — no `goto`, no bitwise operators (`bit32` lib or WoW `bit` lib for bitwise ops), no integer division operator.
- **No `print()` in production** — use `DEFAULT_CHAT_FRAME:AddMessage()` or `QB.UI:Debug()` for in-game logging.
- **WoW API is not available in tests** — `test_runner.lua` stubs the WoW API. If you use a new WoW API, add a stub to the test runner.
- **Addon message size limit** — `SendAddonMessage` payloads are capped at 255 bytes. All messages must go through `Protocol.lua` chunking.
- **SavedVariables load timing** — `QuestBuddyDB` is only populated after `ADDON_LOADED` fires. Do not read it at file-load time.
- **`pairs` ordering** — Lua tables are unordered. Never assume deterministic iteration order for peer lists or quest tables.
