# Equilux design system

The Equilux brand and UI design system, versioned as Markdown spec files. Agents consume it through the
[`equilux-design-system`](../skills/equilux-design-system) skill. Projects consume it by copying the generated token
files.

This is the public edition. It omits the business positioning section of the spec, and the full spec is kept in the
private Equilux repository. Everything visual, including colors, type, logo and rules, is identical.

## Layout

| Path | What it is | Edit? |
| --- | --- | --- |
| [`versions/`](versions) | One complete spec per version, `X.Y.Z.md`. **The source of truth** | Yes: add a new file |
| [`open-questions.md`](open-questions.md) | Every open decision, in one place | Yes |
| [`build/<version>/`](build) | `tokens.json` (DTCG), `tokens.css`, `tailwind.preset.js` (v3), `tailwind-theme.css` (v4) for each approved version, so projects can pin | No, generated |
| [`../skills/equilux-design-system/`](../skills/equilux-design-system) | The skill: `SKILL.md`, hand-written `references/`, `assets/logo/`, plus generated `tokens/`, `references/spec.md` and `references/changelog.md` for the current version | Hand-written parts only |
| [`../scripts/design-tokens.py`](../scripts/design-tokens.py) | The generator | When the format changes |

## Versions

- A version's `status` frontmatter decides its role. Anything starting with `proposed` is a draft for review. Any
  other status is approved.
- **Current** is the highest approved version. It feeds the skill.
- A proposed version newer than current is validated and contrast-checked on every test run, but nothing is built
  from it.
- Approved versions are never edited after release. A correction ships as a new patch version (as 0.3.1 did for
  0.3.0). Use semver from the consumer's point of view:
  - **patch:** corrections to prose, claims and rules, with no token changes
  - **minor:** new tokens or guidance, where existing projects keep working
  - **major:** a renamed, removed or changed token value that projects must act on

## Making a new version

1. Copy the current version file to `versions/<new>.md` and set `version`, `status` and `last_updated`.
2. Change the spec. Keep §11.1 (CSS) and §11.2 (JSON) in agreement, and keep both dark CSS blocks identical. The
   generator refuses a spec where they differ.
3. Add every new color pair to a `| Foreground | Background | Ratio | Passes |` table. The tests recompute every
   ratio and fail if a claim is wrong.
4. Add a §12 changelog entry. For each change a project must make, add an **Update your project** bullet with
   `Find:` hints (strings to search for). Agents use these to catch projects up.
5. Run `python3 scripts/design-tokens.py`, then `bash test/run.sh`, and commit the spec and generated files
   together.
6. To approve a proposed version, change its `status` (for example to `approved`) and repeat step 5. The skill then
   carries the new version.

The generator reads only these Markdown files. If the spec's source ever moves to another tool, only the parser in
`scripts/design-tokens.py` has to change.

## Using it in a project

See the skill's [`SKILL.md`](../skills/equilux-design-system/SKILL.md) ("Using the tokens in a project" and "Two
modes"). In short:

1. Copy the token files of one version into the project unedited.
2. Record that version in `.equilux-design-version`.
3. To upgrade, apply the changelog entries newer than that version.
