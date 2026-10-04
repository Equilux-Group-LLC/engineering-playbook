<!-- BEGIN equilux-issue-linking (managed by install-local.sh; edit claude/CLAUDE.issues.md, not this block) -->
## Issues, commits and pull requests (all projects)

GitHub closes an issue when a commit or PR that names it with a closing keyword merges into the default branch.
Let that close issues; never close one by hand for work that is merging, unless the project uses the integration-branch
exception below.

- Commits that fix an issue and will merge into the default branch end with `Closes #N` (or `Fixes` / `Resolves`).
  Commits that only touch an issue, or land on another branch first, use `Related to #N`.
- PRs into the default branch put `Closes #N` in the description; with no issue, `No issue: <reason>`.
  PRs into any other branch use `Related to #N`.
- One keyword per issue: `Closes #4, closes #5`, not `Closes #4, #5`.
- Before opening a PR, confirm it targets the default branch and its description and a commit carry `Closes #N`.
- Exception, integration default branch: some projects make an integration branch (for example `develop`) the default
  while releases ship from another branch (`main`). Closing keywords would then close issues before the work reaches
  production. Such a project says so in its AGENTS.md, CLAUDE.md or docs (look for a "Linking issues" or similar rule).
  Follow it instead of the rules above, typically: link with `Refs #N` in PRs and commits, never a closing keyword, and
  close the issues by hand after the release. If the project has no such rule, the rules above apply.
- A project's own AGENTS.md / CLAUDE.md rules, and the project docs they point to, take precedence over this block.
<!-- END equilux-issue-linking -->
