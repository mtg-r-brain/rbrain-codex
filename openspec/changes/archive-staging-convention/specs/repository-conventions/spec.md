## ADDED Requirements

### Requirement: Archiving an OpenSpec change is staged with `git add -A`

An archive commit SHALL be staged with `git add -A openspec/` (staging the entire `openspec/` subtree), NOT with `git add <archive-path>` alone.

This is required because archiving relocates `openspec/changes/<name>/` to `openspec/changes/archive/<YYYY-MM-DD>-<name>/` and updates the canonical spec(s) under `openspec/specs/`, and neither the `openspec-archive-change` skill (which uses a shell `mv`) nor the `openspec archive` CLI (which copies then deletes) stages the result with git: afterwards `git status` shows the source paths as deleted and the new archive directory as untracked. Staging only the new archive path produces a commit that adds the archived copy while leaving the pre-archive `openspec/changes/<name>/` directory in the working tree — an incomplete archive.

An archive commit SHALL contain: the deletion of the pre-archive change directory, the new archive directory, and any updated canonical spec files. Review SHALL reject an archive commit in which the pre-archive change directory still exists in the tree.

#### Scenario: Archive commit stages the move and the spec update

- **WHEN** a contributor archives a change (via the skill or the `openspec archive` CLI) and stages with `git add -A openspec/`
- **THEN** the commit SHALL include the removal of `openspec/changes/<name>/`, the added `openspec/changes/archive/<date>-<name>/`, and any modified `openspec/specs/<capability>/spec.md`

#### Scenario: Staging only the new path is rejected

- **WHEN** a contributor stages only the new archive directory (`git add openspec/changes/archive/<date>-<name>`) and commits
- **THEN** the pre-archive `openspec/changes/<name>/` directory SHALL remain in the tree; this is an incomplete archive and SHALL be rejected at review
