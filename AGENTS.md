# AGENTS.md

## Git Guidelines

In these guidelines, `main` and `origin` mean the repository's default branch and primary remote.

- Take responsibility and accountability for local Git as part of implementation. Handle routine Git work quietly and autonomously. Do not wait for the user to request commits or involve them in routine commit decisions.

- Choose commit boundaries by purpose and completeness, not by individual edits or messages. Proactively commit each completed atomic changeset—one coherent change with a single purpose—before moving on to unrelated work.

- Keep the working tree clean between completed tasks by committing your work. If unrelated changes are present or appear during the task, preserve them and ask how to proceed. Never discard work or use destructive cleanup to obtain a clean working tree.

- Never commit secrets. Exclude temporary artifacts from commits and add appropriate ignore rules for them.

- Use Conventional Commits.

- Work directly on `main` by default. Create, switch, or delete branches or worktrees only when requested or authorized.

- Begin each new task from updated local `main`: fetch from `origin` and fast-forward `main` when it is behind `origin/main`. Preserve unpushed local commits; if the histories have diverged, propose a reconciliation approach for the user's approval. Create authorized feature branches from the resulting `main`. Continue an existing task on its existing branch.

- Before local feature-branch integration or opening a pull request, fetch again and rebase the feature branch onto `origin/main`.

- For authorized local integration, fast-forward `main` to the feature branch. If this fails, resolve the divergence within the authorized scope or propose a solution for the user's approval; do not fall back to creating a merge commit.

- For the pull-request workflow, push the feature branch and open the PR only as authorized. Wait for review approval and satisfaction of applicable merge requirements. Use Squash and merge only when merging is also authorized; permission to publish or open a PR does not imply permission to merge it.

- When undoing committed changes, prefer a targeted revert commit that preserves subsequent work.

- Feature-branch integration, pushing, publishing, opening or merging pull requests, and creating releases require explicit user authorization. Routine fetching and fast-forward updates from upstream are permitted. Force-pushing, including with `--force-with-lease`, requires specific authorization for that operation, even after a rebase.

- Involve the user when authorization is required or a blocker cannot be resolved within the current task. Routine successful Git operations do not need a separate report.
