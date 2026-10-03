# AGENTS.md

## Git Guidelines

### Local ownership and commits

* **Own local Git.** Treat inspection, staging, and commits as part of implementation. Handle them quietly and autonomously; do not wait for a commit request or ask the user to choose routine commit boundaries. Honor explicit instructions not to commit.
* **Commit by purpose.** Commit each completed atomic changeset before moving to unrelated work: one coherent purpose, including necessary tests and documentation. Boundaries follow completeness, not individual edits or messages.
* **Establish the baseline.** Before editing, inspect the current branch and staged, unstaged, and untracked changes. Distinguish task work from existing work; recheck before committing so changes made concurrently are not swept in.
* **Isolate rather than stop.** A dirty tree or unrelated staged work is not, by itself, a blocker. Commit only task-related changes, using selective staging or another safe isolation method. Preserve unrelated content and its staged/unstaged state, including when changes share a file. Do not discard, overwrite, stash, or commit other work merely to simplify your commit. Ask only when ownership or overlap cannot be resolved safely within scope.
* **Verify the commit.** Review the exact proposed contents and run applicable checks before committing; exclude secrets and accidental artifacts. Fix failures caused by the change. Distinguish pre-existing failures and unavailable checks from regressions, and disclose verification limits rather than silently skipping checks or treating every unrelated failure as a commit blocker. Verify the resulting commit and remaining Git state.
* **Finish your work, not everybody's.** Leave no completed task changes uncommitted unless the user requested otherwise or a concrete blocker remains. Preserved unrelated work may legitimately leave the tree dirty. Never use destructive cleanup to manufacture cleanliness. Report exceptions and necessary handoff information, not routine Git narration.
* Use Conventional Commits. Exclude temporary artifacts and add appropriate ignore rules when needed.

### Branches and synchronization

* Work directly on `main` by default; continue an existing task on its existing branch. Create, switch, or delete branches or worktrees only when requested or authorized. Do not abandon an in-progress branch merely because a new message arrives.
* Begin a new task on updated local `main`: fetch from `origin` and fast-forward when behind `origin/main`, then create an authorized feature branch if needed. Routine fetching and fast-forward updates are permitted; preserve unpushed local commits and unrelated working-tree/index changes. If the required switch or update cannot be performed safely within existing authority, report that specific blocker. If histories have diverged, propose reconciliation for approval rather than resetting or rewriting `main`.

### Integration and publication

* Before authorized local feature-branch integration or opening a pull request, fetch again and rebase the feature branch onto `origin/main`. Resolve only conflicts whose intended outcome is clear within task scope; otherwise ask. This workflow does not authorize rewriting `main` or force-pushing.
* For authorized local integration, fast-forward `main` to the feature branch. If that fails, resolve divergence within the authorized scope or propose a solution for approval; do not fall back to a merge commit.
* Push a feature branch and open a pull request only as authorized. Merge only after review approval, satisfaction of applicable merge requirements, and authorization to merge; use Squash and merge. Permission to publish or open a PR is not permission to merge it.
* Feature-branch integration, pushing, publication, opening or merging PRs, and releases require explicit user authorization. Force-pushing, including `--force-with-lease`, requires specific authorization for that operation, even after an authorized rebase.
* When undoing committed changes, prefer a targeted revert commit that preserves subsequent work. Never discard work or rewrite history merely to obtain a clean tree.
