## Why

Archiving an OpenSpec change has produced an incomplete git commit ~4 times across the platform in two weeks (tracked as Finding C). Root-cause audit:

- The generated `openspec-archive-change` skill relocates the change with a shell `mv`, then syncs specs separately. The `openspec archive` CLI instead **copies then deletes** and applies the spec deltas. Either way, `git status` afterwards shows the source paths as **deleted** and the new `openspec/changes/archive/<date>-<name>/` directory as **untracked** — git does not record a move until both sides are staged.
- Neither path stages git at all. A `git add <archive-path>` (the intuitive move) stages the new directory but **misses the source-path deletions**, producing a commit that adds the archive copy while leaving the original change directory in the tree.
- The skill is auto-generated (`generatedBy: openspec 1.4.1`), so a local edit to `SKILL.md` is not durable (`openspec update` regenerates it). The fix therefore belongs in a codified convention (and, separately, upstream openspec), not a local skill patch.

The reliable, tool-agnostic remedy is to stage the whole `openspec/` subtree.

## What Changes

- ADD a `repository-conventions` requirement: archiving an OpenSpec change SHALL be committed by staging the entire `openspec/` subtree (`git add -A openspec/`), not just the new archive path, so the source-directory deletions and the updated canonical spec are included. Review SHALL reject an archive commit that leaves the pre-archive change directory in the tree.

## Capabilities

### Modified Capabilities

- `repository-conventions`: ADD requirement "Archiving an OpenSpec change is staged with `git add -A`".

## Impact

- **Convention only** (codex `repository-conventions`). Applies to every `rbrain-*` repo and every agent/contributor performing an archive, via skill or CLI.
- **No code.** Does not edit the generated `openspec-archive-change` skill (non-durable); upstream improvement to openspec is a separate feedback channel.
- **Dogfood:** this change is itself archived with `git add -A openspec/`.
