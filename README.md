# QuestBuddy

QuestBuddy is a small World of Warcraft retail party addon focused on one job: show your buddy's quest progress with minimal friction.

## Features

- Party-only QuestBuddy peer detection
- Session-only quest snapshots with freshness states
- Retail-safe addon chat prefix registration and bounded snapshot chunking
- Focused buddy tracker overlay for watched quests
- Compact overview window for shared, buddy-only, and mine-only quests
- Minimal slash commands and options

## Install

1. Place this addon in your AddOns directory.
2. Make sure the addon folder is named `QuestBuddy` when installed in-game.
3. Make sure the TOC file is named `QuestBuddy.toc`.
4. Launch the client and enable QuestBuddy on the character selection screen.

## Commands

- `/qb` toggles the main window
- `/qb refresh` requests fresh buddy snapshots
- `/qb options` opens Interface Options

## Local Checks

Run the local regression suite from the addon root:

```powershell
./check.ps1
```
