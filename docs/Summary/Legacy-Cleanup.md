# Legacy Cleanup

## Scope

This document records the latest repository-wide legacy scan and the cleanup
actions that were safe to apply without changing runtime behavior.

## Cleaned Up

- Removed tracked TestSprite cache files from `docs/qa/testsprite/tmp/`.
- Removed local-only `test/.idea/` workspace files from the working tree.
- Archived unrelated TagMaster and TagKB reference docs under `docs/archive/`.
- Fixed stale documentation paths in `docs/Role/AGENTS.md`.
- Updated `.gitignore` to block local QA cache and machine-specific artifacts.

## High-Risk Findings

- TestSprite generated config files contained a machine-local API key.
- Generated QA cache should never be committed again.

## Confirmed Legacy Or Non-Active Items

- `docs/archive/tagmaster_legacy/role/AGENTS_ADD.md`
- `docs/archive/tagkb-ui/TAGKB_*.md`

These files are retained only as archive material and are not part of the
active MuseArchive workflow.

## Remaining Candidates To Review Later

- Platform template settings in Android, iOS, web, and macOS project files.
- Backup/restore testability refactor for `AlbumRepository`.
- Additional UI and autosave regression tests.
