# QuestBuddy

QuestBuddy is a small World of Warcraft party addon focused on one job: show your buddy's quest progress with minimal friction.

For implementation details, protocol notes, and contributor-facing guidance, see [CLAUDE.md](./CLAUDE.md).

## What It Does

- Detects other QuestBuddy users in your current party
- Tracks one focused buddy at a time with `Live`, `Updating`, `Stale`, and `Offline` freshness states
- Shows watched shared quests in a focused tracker overlay
- Shows `Shared Quests`, `Buddy Only`, and `Mine Only` sections in a compact main window
- Lets you request a fresh sync manually with `Refresh` or `/qb refresh`
- Includes a built-in `Simulate` / `Clear Sim` mode for solo UI preview and local UI testing
- Keeps the option surface small: overlay toggle, shared-only filtering, auto-focus, window lock, and stale timeout

## Install

1. Place this addon in your AddOns directory.
2. Make sure the addon folder is named `QuestBuddy` when installed in-game.
3. Make sure the manifest file is named `QuestBuddy.toc`.
4. Launch the client and enable QuestBuddy on the character selection screen.

## Usage

- Both players need QuestBuddy enabled before buddy data appears.
- QuestBuddy only exchanges data with current party members.
- Buddy quest data is session-scoped during play, not a long-term quest history log.
- Open `/qb`, then choose the buddy you want to follow from the dropdown when more than one QuestBuddy peer is present.

## Docs

- [AGENTS.md](./AGENTS.md) for repository guidance
- [CLAUDE.md](./CLAUDE.md) for contributor and technical notes
- [ROADMAP.md](./ROADMAP.md) for accepted follow-up work and candidate directions

## Commands

- `/qb` toggles the main window
- `/qb refresh` requests fresh buddy snapshots
- `/qb options` opens Interface Options
- `/qb debug` prints quest-log debug details to chat for troubleshooting

## Main Window

- `Refresh` triggers the same manual sync flow as `/qb refresh`.
- `Simulate` creates a fake buddy from your current local quest list so you can preview the UI without another player.
- `Clear Sim` removes the simulated buddy and returns the window to live peers.
- The dropdown selects the focused buddy shown in the main window and tracker overlay.

## Options

- `Enable tracker overlay` shows the focused buddy beneath the quest watch area.
- `Show only shared quests in window` hides the `Buddy Only` and `Mine Only` sections.
- `Auto-focus a single buddy` keeps focus on the only available QuestBuddy peer.
- `Lock main window` prevents dragging the main QuestBuddy window.
- `Stale timeout` controls when buddy data moves from `Live` to `Stale`.

## Compatibility and Limits

- `QuestBuddy.toc` currently declares interface values `120001` and `110207`.
- QuestBuddy is built for party and small-group quest visibility, not raid-wide coordination or long-term quest history.
- `QuestBuddyDB` persists options and window state; buddy quest snapshots are exchanged for the current session.

## Local Checks

Run the local regression suite from the addon root. `lua` or `luajit` must be available on `PATH`.

```powershell
./check.ps1
```
