# AGENTS.md — QuestBuddy

This file is the primary handoff for automated agents and contributors working in this repository.

## Repository Rules

- Keep changes surgical and scoped to the user request.
- Preserve the existing Lua 5.1 addon structure and module load order.
- Run `./check.ps1` after changes that affect code or docs.
- Prefer repository evidence over assumptions when updating docs.
- Do not invent roadmap items or architecture decisions that are not already present in the codebase.

## Useful Entry Points

- [README.md](./README.md) for the user-facing project summary.
- [CLAUDE.md](./CLAUDE.md) for detailed contributor and agent notes.
- [ROADMAP.md](./ROADMAP.md) for planned follow-up work.

## Notes

- The addon uses `QuestBuddyDB` for saved variables.
- The local regression suite lives in `tests/test_runner.lua` and is invoked by `check.ps1`.
