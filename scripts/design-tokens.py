#!/usr/bin/env python3
"""Build the Equilux design-system artifacts from the versioned spec files.

Usage: design-tokens.py [--check] [--root DIR]
  --check   rebuild in memory and report stale or stray files; write nothing
  --root    repository root (default: the repository this script lives in)

Input:  design-system/versions/X.Y.Z.md. Each is a full spec with frontmatter (version, status, last_updated),
        a §4.2 type-scale table, a §11.1 CSS block, a §11.2 JSON block and a §12 changelog.
Current: the highest version whose status does not start with "proposed".
Output (GENERATED, never edit by hand):
  design-system/build/<version>/      tokens.json, tokens.css, tailwind.preset.js, tailwind-theme.css for every
                                      non-proposed version, so projects can pin one
  skills/equilux-design-system/tokens/      the same four files for the current version
  skills/equilux-design-system/references/  spec.md and changelog.md from the current version

Every spec is validated first: its CSS and JSON must agree, and both dark-theme CSS blocks must match.
Exit codes: 0 ok, 1 stale outputs (--check), 2 bad spec.
"""
import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

GENERATOR = "scripts/design-tokens.py"
SKILL_DIR = "skills/equilux-design-system"
BUILD_DIR = "design-system/build"
VERSIONS_DIR = "design-system/versions"
GENERATED_REFERENCES = ("spec.md", "changelog.md")
DARK_SELECTORS = ('@media (prefers-color-scheme: dark) :root:not([data-theme="light"])', ':root[data-theme="dark"]')

HEX = re.compile(r"^#[0-9A-Fa-f]{6}$")
RGBA = re.compile(r"^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)$")


class SpecError(Exception):
    pass


# ---------- parsing ----------

def kebab(name):
    """textSecondary -> text-secondary, gray700 -> gray-700."""
    name = re.sub(r"([a-z])([A-Z])", r"\1-\2", name)
    name = re.sub(r"([A-Za-z])(\d)", r"\1-\2", name)
    return name.lower()


def frontmatter(text):
    match = re.match(r"---\n(.*?)\n---\n", text, re.S)
    if not match:
        raise SpecError("missing frontmatter")
    meta = {}
    for line in match.group(1).splitlines():
        key, sep, value = line.partition(":")
        if sep:
            meta[key.strip()] = value.strip()
    return meta


def section(text, number):
    """Body of the heading that starts with the given number, e.g. '11.1' or '12', up to the next heading
    of the same or a higher level."""
    match = re.search(rf"^(#+) {re.escape(number)}\.?\s.*$", text, re.M)
    if not match:
        raise SpecError(f"missing section §{number}")
    level = len(match.group(1))
    rest = text[match.end():]
    end = re.search(rf"^#{{1,{level}}} ", rest, re.M)
    return rest[: end.start()] if end else rest


def fenced(body, lang, where):
    match = re.search(rf"```{lang}\n(.*?)```", body, re.S)
    if not match:
        raise SpecError(f"no ```{lang} block in §{where}")
    return match.group(1)


def table_rows(body, header):
    """Rows (as cell lists) of every Markdown table in body whose header starts with the given cells."""
    rows, active = [], False
    for line in body.splitlines():
        if not line.startswith("|"):
            active = False
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if cells[: len(header)] == header:
            active = True
        elif active and not set(line) <= set("|-: "):
            rows.append(cells)
    return rows


def css_blocks(css):
    """{selector: {property: value}} for every rule; nested rules get the enclosing at-rule prefixed."""
    blocks, stack, buf = {}, [], ""
    for char in re.sub(r"/\*.*?\*/", "", css, flags=re.S):
        if char == "{":
            stack.append(" ".join(buf.split()))
            buf = ""
        elif char == "}":
            decls = blocks.setdefault(" ".join(stack), {})
            for decl in buf.split(";"):
                prop, sep, value = decl.partition(":")
                if sep and prop.strip().startswith("--"):
                    decls[prop.strip()] = " ".join(value.split())
            stack.pop()
            buf = ""
        else:
            buf += char
    return {k: v for k, v in blocks.items() if v}


@dataclass
class Spec:
    version: str
    status: str
    text: str
    meta: dict
    css: str
    tokens: dict
    type_scale: list
    changelog: str
    path: Path = None

    @classmethod
    def parse(cls, text, path=None):
        meta = frontmatter(text)
        for key in ("version", "status"):
            if key not in meta:
                raise SpecError(f"frontmatter has no {key}")
        if not re.fullmatch(r"\d+\.\d+\.\d+", meta["version"]):
            raise SpecError(f"version {meta['version']!r} is not X.Y.Z")
        css = fenced(section(text, "11.1"), "css", "11.1")
        try:
            tokens = json.loads(fenced(section(text, "11.2"), "json", "11.2"))
        except json.JSONDecodeError as err:
            raise SpecError(f"§11.2 JSON does not parse: {err}") from err
        type_scale = []
        for cells in table_rows(section(text, "4.2"), ["Token", "Size"]):
            token, size, line_height, family, weight = cells[:5]
            size_match = re.search(r"([\d.]+)rem", size)
            weight_match = re.match(r"(\d+)", weight)
            if not (size_match and weight_match):
                raise SpecError(f"§4.2 row {token} has no rem size or numeric weight")
            entry = {"name": token.strip("`"), "size": f"{size_match.group(1)}rem", "lineHeight": line_height,
                     "family": family, "weight": int(weight_match.group(1))}
            tracking = re.search(r"([+-]?[\d.]+em) tracking", weight)
            if tracking:
                entry["letterSpacing"] = tracking.group(1).lstrip("+")
            if "uppercase" in weight:
                entry["textTransform"] = "uppercase"
            type_scale.append(entry)
        if not type_scale:
            raise SpecError("§4.2 has no type-scale rows")
        return cls(meta["version"], meta["status"], text, meta, css, tokens, type_scale,
                   section(text, "12").strip(), path)

    @property
    def key(self):
        return tuple(int(p) for p in self.version.split("."))

    @property
    def proposed(self):
        return self.status.lower().startswith("proposed")


def load_specs(root):
    specs = []
    for path in sorted(Path(root, VERSIONS_DIR).glob("*.md")):
        try:
            spec = Spec.parse(path.read_text(), path)
        except SpecError as err:
            raise SpecError(f"{path.name}: {err}") from err
        if path.stem != spec.version:
            raise SpecError(f"{path.name}: frontmatter says version {spec.version}")
        specs.append(spec)
    return sorted(specs, key=lambda s: s.key)


def current(specs):
    approved = [s for s in specs if not s.proposed]
    if not approved:
        raise SpecError("no approved version: every version file is proposed")
    return approved[-1]


def buildable(specs):
    """Versions a project can build from now: the current one and any newer proposals."""
    cur = current(specs)
    return [s for s in specs if s.key >= cur.key]


# ---------- validation ----------

def resolve(name, decls, seen=()):
    value = decls.get(name)
    if value is None:
        raise SpecError(f"{name} is not declared")
    match = re.fullmatch(r"var\((--[\w-]+)\)", value)
    if match:
        if match.group(1) in seen:
            raise SpecError(f"{name} refers to itself")
        return resolve(match.group(1), decls, seen + (name,))
    return value


def norm(value):
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return f"{value}px"
    value = " ".join(str(value).split())
    if HEX.match(value):
        return value.upper()
    match = RGBA.match(value)
    if match:
        r, g, b, a = match.groups()
        return f"rgba({r},{g},{b},{float(a) if a else 1.0:g})"
    return value


def css_name(path):
    """Spec JSON path -> the CSS custom property that must carry the same value, plus which CSS block."""
    group, *rest = path
    if group == "color":
        family, key = rest
        return (f"--eqx-{kebab(key)}" if family == "neutral" else f"--eqx-{family}-{kebab(key)}"), ":root"
    if group == "semantic":
        theme, key = rest
        return f"--eqx-{kebab(key)}", DARK_SELECTORS[0] if theme == "dark" else ":root"
    return "--eqx-" + "-".join(kebab(p) for p in path), ":root"


def leaves(node, path=()):
    if isinstance(node, dict):
        for key, value in node.items():
            yield from leaves(value, path + (key,))
    else:
        yield path, node


def validate(spec):
    blocks = css_blocks(spec.css)
    if ":root" not in blocks:
        raise SpecError("§11.1 has no bare :root block")
    for selector in DARK_SELECTORS:
        if selector not in blocks:
            raise SpecError(f"§11.1 has no {selector} block")
    if blocks[DARK_SELECTORS[0]] != blocks[DARK_SELECTORS[1]]:
        raise SpecError("§11.1 dark blocks differ: prefers-color-scheme and [data-theme=\"dark\"] must match")
    missing = sorted(set(blocks[DARK_SELECTORS[0]]) - set(blocks[":root"]))
    if missing:
        raise SpecError(f"§11.1 themed tokens not declared in bare :root: {', '.join(missing)}")
    problems, matched = [], {sel: set() for sel in (":root", DARK_SELECTORS[0])}
    for path, value in leaves(spec.tokens):
        name, selector = css_name(path)
        decls = dict(blocks[":root"], **blocks[selector]) if selector != ":root" else blocks[":root"]
        if name not in decls:
            problems.append(f"{'.'.join(path)} has no {name} in §11.1")
            continue
        matched[selector].add(name)
        css_value = resolve(name, decls)
        if path[0] == "font":
            css_value = css_value.split(",")[0].strip().strip("'\"")
        if norm(css_value) != norm(value):
            problems.append(f"{name}: §11.1 says {css_value}, §11.2 says {value}")
    for selector, names in matched.items():
        extra = sorted(set(blocks[selector]) - names)
        if extra:
            problems.append(f"§11.1 {selector} declares {', '.join(extra)} with no §11.2 entry")
    if problems:
        raise SpecError("§11.1 and §11.2 disagree:\n  " + "\n  ".join(problems))
    fonts = {v: k for k, v in spec.tokens.get("font", {}).items()}
    for entry in spec.type_scale:
        if entry["family"] not in fonts:
            raise SpecError(f"§4.2 {entry['name']} uses {entry['family']}, which is not a §11.2 font")
    return blocks


# ---------- contrast ----------

def channel(value):
    value /= 255
    return value / 12.92 if value <= 0.03928 else ((value + 0.055) / 1.055) ** 2.4


def luminance(rgb):
    r, g, b = (channel(v) for v in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def to_rgb(value):
    value = norm(value)
    if HEX.match(value):
        return [int(value[i:i + 2], 16) for i in (1, 3, 5)], 1.0
    match = RGBA.match(value)
    if match:
        r, g, b, a = match.groups()
        return [int(r), int(g), int(b)], float(a) if a else 1.0
    raise SpecError(f"not a color: {value}")


def contrast(fg, bg):
    (fg_rgb, alpha), (bg_rgb, _) = to_rgb(fg), to_rgb(bg)
    mixed = [alpha * f + (1 - alpha) * b for f, b in zip(fg_rgb, bg_rgb)]
    hi, lo = sorted((luminance(mixed), luminance(bg_rgb)), reverse=True)
    return (hi + 0.05) / (lo + 0.05)


@dataclass
class ContrastRow:
    fg: str
    bg: str
    alpha: float
    claimed: float
    required: float
    measured: float = field(default=0.0)

    @property
    def label(self):
        return f"{self.fg}{f' @{round(self.alpha * 100)}%' if self.alpha < 1 else ''} on {self.bg}"

    def problems(self):
        out = []
        if abs(round(self.measured, 1) - self.claimed) > 0.051:
            out.append(f"{self.label}: claimed {self.claimed} : 1, measures {self.measured:.2f} : 1")
        if self.measured < self.required:
            out.append(f"{self.label}: {self.measured:.2f} : 1 is under the {self.required} : 1 it claims to pass")
        return out


def required_ratio(passes):
    passes = passes.lower()
    if "large" in passes or "non-text" in passes:
        return 3.0
    if "aaa" in passes:
        return 7.0
    return 4.5


def contrast_rows(spec):
    """Every row of every 'Foreground | Background | Ratio | Passes' table, measured against the palette."""
    decls = css_blocks(spec.css).get(":root", {})
    rows = []
    for fg_cell, bg_cell, ratio_cell, passes in (r[:4] for r in table_rows(spec.text, ["Foreground", "Background", "Ratio"])):
        fg = re.findall(r"`([\w-]+)`", fg_cell)[0]
        alpha_match = re.search(r"@(\d+)%", fg_cell)
        alpha = int(alpha_match.group(1)) / 100 if alpha_match else 1.0
        bgs = re.findall(r"`([\w-]+)`", bg_cell)
        ratios = [float(x) for x in re.findall(r"[\d.]+", ratio_cell.split(":")[0])]
        if len(ratios) != len(bgs):
            raise SpecError(f"contrast row {fg_cell} | {bg_cell}: {len(bgs)} backgrounds but {len(ratios)} ratios")
        for bg, claimed in zip(bgs, ratios):
            fg_rgb, _ = to_rgb(resolve(f"--eqx-{fg}", decls))
            fg_value = "rgba({},{},{},{})".format(*fg_rgb, alpha)
            row = ContrastRow(fg, bg, alpha, claimed, required_ratio(passes))
            row.measured = contrast(fg_value, resolve(f"--eqx-{bg}", decls))
            rows.append(row)
    return rows


# ---------- rendering ----------

def header(spec, comment):
    lines = [f"Equilux design tokens {spec.version} ({spec.status.split(' ')[0]}).",
             f"GENERATED by {GENERATOR} from {VERSIONS_DIR}/{spec.version}.md. Do not edit; change the spec and rerun."]
    if comment == "/*":
        return "/*\n" + "".join(f" * {line}\n" for line in lines) + " */\n"
    return "".join(f"{comment} {line}\n" for line in lines)


def dtcg_value(path, value, spec, literal_paths, blocks):
    if path[0] == "font":
        stack = [f.strip().strip("'\"") for f in blocks[":root"][f"--eqx-font-{kebab(path[-1])}"].split(",")]
        return {"$type": "fontFamily", "$value": stack}
    if isinstance(value, (int, float)):
        return {"$type": "dimension", "$value": f"{value}px"}
    value = str(value)
    if HEX.match(value) or RGBA.match(value):
        alias = literal_paths.get(norm(value)) if path[0] != "color" else None
        return {"$type": "color", "$value": "{" + alias + "}" if alias else value}
    if re.fullmatch(r"\d+ms", value):
        return {"$type": "duration", "$value": value}
    match = re.fullmatch(r"cubic-bezier\(([^)]*)\)", value)
    if match:
        return {"$type": "cubicBezier", "$value": [float(x) for x in match.group(1).split(",")]}
    raise SpecError(f"§11.2 {'.'.join(path)}: cannot type value {value!r}")


def render_json(spec, blocks):
    literal_paths = {norm(v): ".".join(p) for p, v in leaves(spec.tokens.get("color", {}), ("color",))}
    out = {"$description": header(spec, "").replace("\n ", " ").strip(),
           "$extensions": {"com.equilux.design-system": {"version": spec.version, "status": spec.status,
                                                         "lastUpdated": spec.meta.get("last_updated", "")}}}
    for path, value in leaves(spec.tokens):
        node = out
        keys = [kebab(k) if path[0] == "semantic" else k for k in path]
        for key in keys[:-1]:
            node = node.setdefault(key, {})
        node[keys[-1]] = dtcg_value(path, value, spec, literal_paths, blocks)
    fonts = {v: k for k, v in spec.tokens["font"].items()}
    out["typography"] = {}
    for entry in spec.type_scale:
        value = {"fontFamily": "{font." + fonts[entry["family"]] + "}", "fontSize": entry["size"],
                 "lineHeight": float(entry["lineHeight"]), "fontWeight": entry["weight"]}
        if "letterSpacing" in entry:
            value["letterSpacing"] = entry["letterSpacing"]
        token = {"$type": "typography", "$value": value}
        if "textTransform" in entry:
            token["$extensions"] = {"com.equilux.design-system": {"textTransform": entry["textTransform"]}}
        out["typography"][entry["name"]] = token
    return json.dumps(out, indent=2) + "\n"


def render_css(spec):
    fonts = {v: k for k, v in spec.tokens["font"].items()}
    lines = ["", "/* Type scale (§4.2), generated: --eqx-text-<token> plus --line-height, --weight, --family. */",
             ":root {"]
    rules = []
    for e in spec.type_scale:
        n = f"--eqx-text-{e['name']}"
        lines += [f"  {n}: {e['size']};", f"  {n}--line-height: {e['lineHeight']};", f"  {n}--weight: {e['weight']};",
                  f"  {n}--family: var(--eqx-font-{kebab(fonts[e['family']])});"]
        extra = ""
        if "letterSpacing" in e:
            lines.append(f"  {n}--tracking: {e['letterSpacing']};")
            extra += f" letter-spacing: var({n}--tracking);"
        if "textTransform" in e:
            extra += f" text-transform: {e['textTransform']};"
        rules.append(f".eqx-type-{e['name']} {{ font-family: var({n}--family); font-size: var({n}); "
                     f"line-height: var({n}--line-height); font-weight: var({n}--weight);{extra} }}")
    lines += ["}", ""] + rules
    return header(spec, "/*") + "\n" + spec.css.rstrip() + "\n" + "\n".join(lines) + "\n"


def tailwind_entries(spec, blocks):
    """(group, key, css value) triples shared by both Tailwind outputs."""
    literal = {css_name(p)[0] for p, _ in leaves(spec.tokens.get("color", {}), ("color",))}
    entries = []
    for name in blocks[":root"]:
        short = name[len("--eqx-"):]
        if name.startswith("--eqx-font-"):
            entries.append(("font", short[len("font-"):], f"var({name})"))
        elif name.startswith("--eqx-space-"):
            entries.append(("spacing", short, f"var({name})"))
        elif name.startswith("--eqx-radius-"):
            entries.append(("radius", short[len("radius-"):], f"var({name})"))
        elif name in literal:
            entries.append(("color", f"eqx-{short}", f"var({name})"))
        else:
            try:
                to_rgb(resolve(name, blocks[":root"]))
            except SpecError:
                continue
            entries.append(("color", short, f"var({name})"))
    return entries


def js_key(key):
    return key if re.fullmatch(r"[A-Za-z_]\w*", key) else f"'{key}'"


def render_preset(spec, blocks):
    groups = {"color": "colors", "spacing": "spacing", "radius": "borderRadius", "font": "fontFamily"}
    lines = [header(spec, "//").rstrip(), "//",
             "// Tailwind v3 preset: module.exports = { presets: [require('./tailwind.preset.js')] }.",
             "// Values are the --eqx-* CSS variables, so import tokens.css too; dark mode then follows the theme.",
             "module.exports = {", "  theme: {", "    extend: {"]
    entries = tailwind_entries(spec, blocks)
    for group, tw in groups.items():
        lines.append(f"      {tw}: {{")
        lines += [f"        {js_key(k)}: '{v}'," for g, k, v in entries if g == group]
        lines.append("      },")
    lines.append("      fontSize: {")
    for e in spec.type_scale:
        opts = f"lineHeight: '{e['lineHeight']}', fontWeight: '{e['weight']}'"
        if "letterSpacing" in e:
            opts += f", letterSpacing: '{e['letterSpacing']}'"
        lines.append(f"        {js_key(e['name'])}: ['{e['size']}', {{ {opts} }}],")
    lines += ["      },", "    },", "  },", "};", ""]
    return "\n".join(lines)


def render_theme_css(spec, blocks):
    prefix = {"color": "--color-", "spacing": "--spacing-", "radius": "--radius-", "font": "--font-"}
    lines = [header(spec, "/*").rstrip(),
             "/* Tailwind v4: @import \"tailwindcss\"; @import \"./tokens.css\"; @import \"./tailwind-theme.css\"; */",
             "@theme inline {"]
    lines += [f"  {prefix[g]}{k}: {v};" for g, k, v in tailwind_entries(spec, blocks)]
    for e in spec.type_scale:
        n = f"--text-{e['name']}"
        lines += [f"  {n}: {e['size']};", f"  {n}--line-height: {e['lineHeight']};", f"  {n}--font-weight: {e['weight']};"]
        if "letterSpacing" in e:
            lines.append(f"  {n}--letter-spacing: {e['letterSpacing']};")
    lines += ["}", ""]
    return "\n".join(lines)


def render(spec):
    blocks = validate(spec)
    return {"tokens.json": render_json(spec, blocks), "tokens.css": render_css(spec),
            "tailwind.preset.js": render_preset(spec, blocks), "tailwind-theme.css": render_theme_css(spec, blocks)}


def generated_reference(spec, title, body):
    return (f"<!-- GENERATED by {GENERATOR} from {VERSIONS_DIR}/{spec.version}.md. Do not edit. -->\n"
            + (f"# {title}\n\n{body}\n" if title else body))


def outputs(root):
    specs = load_specs(root)
    cur = current(specs)
    files = {}
    for spec in specs:
        if spec.proposed:
            validate(spec)
            continue
        for name, content in render(spec).items():
            files[f"{BUILD_DIR}/{spec.version}/{name}"] = content
    for name, content in render(cur).items():
        files[f"{SKILL_DIR}/tokens/{name}"] = content
    files[f"{SKILL_DIR}/references/spec.md"] = generated_reference(cur, None, cur.text)
    files[f"{SKILL_DIR}/references/changelog.md"] = generated_reference(
        cur, f"Equilux design system changelog (current: {cur.version})",
        "Newest first. To bring a project up to date, apply every entry newer than the version in its "
        "`.equilux-design-version`, oldest first, using each entry's Find hints.\n\n" + cur.changelog)
    return files


def stray(root, files):
    """Generated-looking files on disk that the current specs would not produce."""
    found = []
    for base in (Path(root, BUILD_DIR), Path(root, SKILL_DIR, "tokens")):
        if base.exists():
            found += [str(p.relative_to(root)) for p in base.rglob("*") if p.is_file() and p.name != ".DS_Store"]
    return sorted(set(found) - set(files))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--root", default=str(Path(__file__).resolve().parent.parent))
    args = parser.parse_args(argv)
    try:
        files = outputs(args.root)
    except SpecError as err:
        print(f"design-tokens: {err}", file=sys.stderr)
        return 2
    stale = []
    for rel, content in sorted(files.items()):
        target = Path(args.root, rel)
        existing = target.read_text() if target.exists() else None
        if existing == content:
            continue
        if args.check:
            stale.append(rel)
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content)
        print(f"{'created' if existing is None else 'updated'}  {rel}")
    extras = stray(args.root, files)
    if args.check:
        for rel in stale:
            print(f"STALE    {rel}", file=sys.stderr)
        for rel in extras:
            print(f"STRAY    {rel}", file=sys.stderr)
        if stale or extras:
            print(f"Rebuild with: python3 {GENERATOR}", file=sys.stderr)
            return 1
        print("design-tokens: generated files are up to date")
        return 0
    for rel in extras:
        Path(args.root, rel).unlink()
        print(f"removed  {rel}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
