# ROADMAP.md — QuestBuddy

This file tracks accepted follow-up work and evidence-grounded candidate directions for QuestBuddy.

## Current Status

- QuestBuddy is feature-complete for its current scope today: party-only peer detection, session snapshot exchange, a single focused buddy workflow, a tracker overlay, a compact overview window, minimal options, and simulated-peer support for local UI work.
- The addon's current lane remains party and small-group quest visibility. New entries here should extend that lane rather than expand into unrelated addon systems.

## Accepted Work

- No formal roadmap items are committed yet.

## Candidate Directions

These items are suggestions, not commitments. If individual items are accepted later, they may touch `/qb` commands, the options panel, `QuestBuddyDB`, and addon-message protocol behavior.

### Buddy Visibility & Workflow

- Add a multi-buddy summary view for parties larger than a duo so users can scan all peers without repeatedly changing focus.
- Add richer per-quest comparison in the main window, including objective deltas, who is ahead, and last-updated age beside buddy status.
- Add focus helpers such as next or previous buddy actions, or an optional freshest-buddy auto-focus mode, while preserving the current dropdown-first flow.

### Window & Overlay Polish

- Make the tracker overlay movable and persist its anchor and visibility state in `QuestBuddyDB`.
- Make the main window resizable and have row layout respond to width, since width and height already exist in saved state.
- Add sort and filter controls beyond `showOnlySharedQuests`, such as watched-only, ready-to-turn-in, or stale and offline emphasis.

### Sharing Controls & Player Trust

- Add options for manual-only refresh mode and/or limiting outbound snapshots to shared or watched quests, not just limiting display rows.
- Add clearer UI messaging for why data is missing, such as buddy offline, stale, updating, or simply not on the quest.

### Protocol & Data Hardening

- Add transfer diagnostics and retry or backoff behavior for incomplete snapshot transfers instead of only clearing `updating` state on timeout or corruption.
- Add capability or version negotiation so future protocol growth does not rely on a single hard-coded version string.
- Strengthen quest identity and parsing fallback rules where the addon currently relies on title and level keys or parsed objective text.

### Code Health & Refactors

- Extract shared status-color and row-formatting helpers used by `UI.lua` and `Tracker.lua` to reduce duplication.
- Move presentation-oriented quest row building out of `State.lua` so session state remains focused on peer lifecycle and runtime ownership.
- Centralize option and default metadata so `QuestBuddy.lua`, `Options.lua`, and the docs stay in sync.

### Tests, Docs & Release Readiness

- Expand regression coverage around malformed or incomplete transfers, quest-key collisions, quest-log mutation suppression, focus persistence, and empty, stale, and offline rendering.
- Consider breaking `tests/test_runner.lua` into clearer module-oriented sections or files once the harness grows further.
- Add lightweight release-readiness items such as a release checklist, compatibility matrix maintenance, and doc synchronization across `README.md`, `CLAUDE.md`, and this roadmap.

## Roadmap Hygiene

- Candidate directions are idea-bank entries, not accepted commitments.
- Move an item into `Accepted Work` only after it has a scoped implementation plan and explicit approval.
- Keep this document aligned with repository evidence and avoid duplicating status that already lives in code, commit history, or issue tracking.
