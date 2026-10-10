# Agent rules for this repository

## Issues, commits and pull requests

GitHub closes an issue automatically when a commit or pull request that says so is merged into the default
branch (`main`). Let that automation close issues; never close an issue by hand for work that is merging.

- **Commits** that fix or address an issue end their message with `Closes #N`, `Fixes #N` or `Resolves #N`
  when the work merges into `main`. Commits that only touch the issue, or land on another branch first, use
  `Related to #N` instead.
- **Pull requests** into `main` keep the template's `Closes #N` line, filled in with the issue number. With no
  issue, replace it with `No issue: <reason>`. Pull requests into any other branch use `Related to #N`.
- One keyword per issue: `Closes #4, closes #5`, not `Closes #4, #5` (GitHub closes only the first).
- Before opening a pull request, confirm: it targets `main`; the description has `Closes #N`; at least one
  commit for the issue carries a closing keyword.

The `PR Issue Link` check (`scripts/issue-link.sh`) enforces the pull request rule. Other repositories can call
`.github/workflows/issue-link.yml@v1`.
