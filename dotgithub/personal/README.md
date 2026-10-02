# Personal GitHub defaults

Default community files for repositories under `caobhin` that don't have their own.

The engineering and testing playbook, the shared CI checks, and the AI-agent rules live in
[Equilux-Group-LLC/engineering-playbook](https://github.com/Equilux-Group-LLC/engineering-playbook). Personal repositories use them the
same way organization repositories do:

- Set up a project: `bash ~/Developer/engineering-playbook/scripts/bootstrap-repo.sh /path/to/project`
- Shared checks: `uses: Equilux-Group-LLC/engineering-playbook/.github/workflows/verify.yml@v1` (also `secret-scan`,
  `tests-changed`, `ai-review`)

Files here are generated from `dotgithub/personal/` in that repository by `scripts/sync-dotgithub.sh`.
Edit them there, not here.
