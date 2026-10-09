import contextlib
import importlib.util
import io
import json
import re
import shutil
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKILL = ROOT / "skills" / "equilux-design-system"
DESIGN = ROOT / "design-system"

spec = importlib.util.spec_from_file_location("design_tokens", ROOT / "scripts" / "design-tokens.py")
dt = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dt)

HEX = re.compile(r"#[0-9A-Fa-f]{6}\b")

# A small spec with obviously fake values, shaped like a real version file.
FIXTURE = """---
title: Fixture spec
version: {version}
status: {status}
last_updated: 2000-01-01
---

# Fixture

### 3.3 Contrast

| Foreground | Background | Ratio | Passes |
|---|---|---|---|
| `ink` | `sheet` | 21.0 : 1 | AA + AAA |
| `ink` @50% | `sheet` | 3.9 : 1 | AA large text only |

### 4.2 Type scale

| Token | Size | Line-height | Family | Weight |
|---|---|---|---|---|
| `big` | 40px / 2.5rem | 1.1 | Fake Display | 600 |
| `tag` | 12px / 0.75rem | 1.4 | Fake Body | 600 (uppercase, +0.04em tracking) |

## 11. Implementation tokens

### 11.1 CSS custom properties

```css
:root {{
  --eqx-ink: #000000;
  --eqx-sheet: #FFFFFF;
  --eqx-bg: var(--eqx-sheet);
  --eqx-text: var(--eqx-ink);
  --eqx-cta-bg: var(--eqx-ink);
  --eqx-font-display: 'Fake Display', sans-serif;
  --eqx-font-body: 'Fake Body', sans-serif;
  --eqx-space-1: {space}px;
  --eqx-radius-sm: 2px;
}}

@media (prefers-color-scheme: dark) {{
  :root:not([data-theme="light"]) {{
    --eqx-bg: var(--eqx-ink);
    --eqx-text: var(--eqx-sheet);
  }}
}}

:root[data-theme="dark"] {{
  --eqx-bg: var(--eqx-ink);
  --eqx-text: var(--eqx-sheet);
}}
```

### 11.2 JSON design tokens

```json
{{
  "color": {{ "neutral": {{ "ink": "#000000", "sheet": "#FFFFFF" }} }},
  "semantic": {{
    "light": {{ "bg": "#FFFFFF", "text": "#000000" }},
    "dark": {{ "bg": "#000000", "text": "#FFFFFF" }},
    "invariant": {{ "ctaBg": "#000000" }}
  }},
  "font": {{ "display": "Fake Display", "body": "Fake Body" }},
  "space": {{ "1": {space} }},
  "radius": {{ "sm": 2 }}
}}
```

---

## 12. Changelog

- **{version}** (2000-01-01) — Fixture entry.
"""


class FixtureRepo(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.root = Path(self.dir.name)
        (self.root / "design-system" / "versions").mkdir(parents=True)

    def tearDown(self):
        self.dir.cleanup()

    def add(self, version, status="approved", space=4, text=None):
        path = self.root / "design-system" / "versions" / f"{version}.md"
        path.write_text(text if text is not None else FIXTURE.format(version=version, status=status, space=space))
        return path

    def run_main(self, *args):
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            return dt.main(["--root", str(self.root), *args])


class SelectionTest(FixtureRepo):
    def test_current_is_highest_non_proposed_version(self):
        self.add("1.9.0")
        self.add("1.10.0")
        self.add("2.0.0", status="proposed — waiting for review")
        specs = dt.load_specs(self.root)
        self.assertEqual(dt.current(specs).version, "1.10.0")
        self.assertEqual([s.version for s in dt.buildable(specs)], ["1.10.0", "2.0.0"])

    def test_build_writes_pinned_versions_and_skill_for_current_only(self):
        self.add("1.0.0")
        self.add("1.1.0")
        self.add("2.0.0", status="proposed")
        self.assertEqual(self.run_main(), 0)
        builds = sorted(p.name for p in (self.root / "design-system" / "build").iterdir())
        self.assertEqual(builds, ["1.0.0", "1.1.0"])
        tokens = json.loads((self.root / "skills/equilux-design-system/tokens/tokens.json").read_text())
        self.assertEqual(tokens["$extensions"]["com.equilux.design-system"]["version"], "1.1.0")
        spec_copy = (self.root / "skills/equilux-design-system/references/spec.md").read_text()
        self.assertIn("version: 1.1.0", spec_copy)

    def test_no_approved_version_is_an_error(self):
        self.add("1.0.0", status="proposed")
        self.assertEqual(self.run_main(), 2)


class CheckTest(FixtureRepo):
    def test_check_passes_after_build(self):
        self.add("1.0.0")
        self.assertEqual(self.run_main(), 0)
        self.assertEqual(self.run_main("--check"), 0)

    def test_check_fails_after_hand_edit_of_generated_file(self):
        self.add("1.0.0")
        self.run_main()
        css = self.root / "skills/equilux-design-system/tokens/tokens.css"
        css.write_text(css.read_text().replace("#000000", "#010101"))
        self.assertEqual(self.run_main("--check"), 1)

    def test_check_fails_when_spec_changed_without_rebuild(self):
        self.add("1.0.0")
        self.run_main()
        self.add("1.0.0", space=6)
        self.assertEqual(self.run_main("--check"), 1)

    def test_check_fails_on_stray_build_output(self):
        self.add("1.0.0")
        self.run_main()
        stray = self.root / "design-system/build/0.9.0"
        stray.mkdir()
        (stray / "tokens.css").write_text("")
        self.assertEqual(self.run_main("--check"), 1)

    def test_check_writes_nothing(self):
        self.add("1.0.0")
        self.assertEqual(self.run_main("--check"), 1)
        self.assertFalse((self.root / "skills").exists())


class SpecValidationTest(FixtureRepo):
    def test_missing_css_block_is_an_error(self):
        text = FIXTURE.format(version="1.0.0", status="approved", space=4)
        self.add("1.0.0", text=re.sub(r"```css.*?```", "", text, flags=re.S))
        self.assertEqual(self.run_main(), 2)

    def test_css_and_json_disagreeing_is_an_error(self):
        text = FIXTURE.format(version="1.0.0", status="approved", space=4)
        self.add("1.0.0", text=text.replace('"space": { "1": 4 }', '"space": { "1": 5 }'))
        with self.assertRaises(dt.SpecError) as raised:
            dt.render(dt.load_specs(self.root)[0])
        self.assertIn("space-1", str(raised.exception))

    def test_dark_blocks_must_agree(self):
        text = FIXTURE.format(version="1.0.0", status="approved", space=4)
        text = text.replace(':root[data-theme="dark"] {\n  --eqx-bg: var(--eqx-ink);',
                            ':root[data-theme="dark"] {\n  --eqx-bg: var(--eqx-sheet);')
        self.add("1.0.0", text=text)
        self.assertEqual(self.run_main(), 2)

    def test_outputs_carry_type_scale_and_aliases(self):
        self.add("1.0.0")
        out = dt.render(dt.load_specs(self.root)[0])
        tokens = json.loads(out["tokens.json"])
        self.assertEqual(tokens["semantic"]["light"]["bg"]["$value"], "{color.neutral.sheet}")
        self.assertEqual(tokens["typography"]["tag"]["$value"]["letterSpacing"], "0.04em")
        self.assertIn("--eqx-text-big: 2.5rem;", out["tokens.css"])
        self.assertIn("bg: 'var(--eqx-bg)'", out["tailwind.preset.js"])
        self.assertIn("--color-bg: var(--eqx-bg);", out["tailwind-theme.css"])


class ContrastTest(unittest.TestCase):
    def test_fixture_rows_parse_with_opacity(self):
        rows = dt.contrast_rows(dt.Spec.parse(FIXTURE.format(version="1.0.0", status="approved", space=4)))
        self.assertEqual(len(rows), 2)
        self.assertEqual(rows[1].alpha, 0.5)
        self.assertEqual(rows[1].required, 3.0)

    def test_claims_hold_for_every_version_a_project_can_build_from(self):
        specs = dt.load_specs(ROOT)
        for s in dt.buildable(specs):
            rows = dt.contrast_rows(s)
            self.assertGreater(len(rows), 10, s.version)
            for row in rows:
                with self.subTest(version=s.version, row=row.label):
                    self.assertEqual(row.problems(), [])

    def test_checker_catches_the_0_3_0_dark_surface_claims(self):
        # 0.3.0 overstated both rows; 0.3.1 corrects them.
        old = next(s for s in dt.load_specs(ROOT) if s.version == "0.3.0")
        failing = [r.label for r in dt.contrast_rows(old) if r.problems()]
        self.assertEqual(failing, ["paper @72% on navy-700", "green-400 on navy-700"])


class RepoTest(unittest.TestCase):
    def test_generated_files_are_up_to_date(self):
        err = io.StringIO()
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(err):
            status = dt.main(["--root", str(ROOT), "--check"])
        self.assertEqual(status, 0, err.getvalue())

    def test_every_themed_token_is_declared_in_bare_root(self):
        css = (SKILL / "tokens" / "tokens.css").read_text()
        blocks = dt.css_blocks(css)
        bare = blocks[":root"]
        for selector, decls in blocks.items():
            if selector != ":root":
                with self.subTest(selector=selector):
                    self.assertEqual(sorted(set(decls) - set(bare)), [])

    def test_guidance_uses_only_current_palette_hexes(self):
        tokens = json.loads((SKILL / "tokens" / "tokens.json").read_text())
        palette = {h.upper() for h in HEX.findall(json.dumps(tokens))}
        guidance = [SKILL / "SKILL.md", DESIGN / "README.md", DESIGN / "open-questions.md"]
        guidance += [p for p in (SKILL / "references").glob("*.md") if p.name not in dt.GENERATED_REFERENCES]
        for path in guidance:
            with self.subTest(path=path.name):
                invented = {h.upper() for h in HEX.findall(path.read_text())} - palette
                self.assertEqual(sorted(invented), [])

    def test_no_private_positioning_or_foreign_palette_leaks(self):
        # Hex values of another organisation's design system that served as a structural model only.
        foreign = {"#161513", "#449D4C", "#5B574E", "#6B4D00", "#9D7100", "#9DAE9F", "#AEA899", "#C83C05",
                   "#CBC5B5", "#D0E0D0", "#D9D9D9", "#E0DBCD", "#E9EDE9", "#EBA900", "#EFEBE1", "#F0C8C0",
                   "#F5D480", "#FAC130", "#FAE9BF", "#FCFBF8", "#FFD86D"}
        for path in list(DESIGN.rglob("*")) + list(SKILL.rglob("*")):
            if not path.is_file() or path.suffix not in {".md", ".json", ".css", ".js", ".svg"}:
                continue
            text = path.read_text()
            with self.subTest(path=str(path.relative_to(ROOT))):
                self.assertEqual(sorted({h.upper() for h in HEX.findall(text)} & foreign), [])
                for phrase in ("**Positioning:**", "figma.com"):
                    self.assertNotIn(phrase, text)

    def test_logo_assets_present(self):
        for name in ("logo-primary.svg", "logo-reversed.svg", "favicon.svg"):
            self.assertTrue((SKILL / "assets" / "logo" / name).is_file(), name)


if __name__ == "__main__":
    unittest.main()
