# Equilux dashboards and data visualization

Data is central to the brand (§1 pillar "data/geospatial pedigree"), so charts should look deliberate, quiet and
exact. Section numbers (§) refer to `spec.md`. Values live in `../tokens/`.

## Color: what is approved today

The current version has **no chart palette and no status colors**. Until a version that adds them is approved (one
is proposed in `design-system/versions/` in the playbook repository):

- **One series:** use `accent`. Light and dark values both clear 3:1 against `bg` and `surface`.
- **A highlight against context:** use `accent` for the focus series and `text-secondary` for the rest.
- **Two series:** use `accent` and `text-secondary`, and label both directly. `link` is not a third option, because
  in dark theme it resolves to the same green as `accent`.
- **Never** use `highlight` (gold) or `green-400` for marks on light grounds. They fail the 3:1 non-text minimum on
  paper and white (§3.3). Gold is fine as a single annotation or callout marker on dark grounds.
- If the data needs more distinct categories, a diverging scale or status colors, say so and point the user at the
  pending proposal. Don't invent colors.

Read colors from the CSS variables at runtime so charts follow the theme. Don't copy hex values into chart configs.

```js
const css = getComputedStyle(document.documentElement);
const accent = css.getPropertyValue('--eqx-accent').trim();
```

## Choosing the chart

| Question the user is asking | Use |
| --- | --- |
| How do items rank? | Horizontal bar chart, sorted descending, with labels on the axis |
| How does it change over time? | Line chart; bars only for few, discrete periods |
| What share of a whole? | Stacked bar or a single 100% bar; a donut only for 2–3 parts; never 3D or exploded pies |
| How do two measures relate? | Scatter plot |
| What is the one number? | A stat tile (below) and no chart at all |
| Where? | A map, with the dashed-grid motif as a quiet basemap texture only if it doesn't fight the data |

## Marks and type

- Keep it flat: no gradients, shadows or 3D. Use a 1px `border` hairline for gridlines, and only on the value axis.
  Keep axis lines minimal.
- Vary color **by chart or metric, not by category**. A ranked bar chart is one color. Use a second color only to
  highlight a selected or anomalous bar, and also mark it with a label.
- Label lines and bars directly instead of using a legend when there are four or fewer series.
- Set numbers, axis ticks and data labels in IBM Plex Mono (`data` token) and titles in Inter. Space Grotesk is for
  page headings only, never for tick labels.
- Format numbers for the user's locale (thousands separators, units, dates). Show units once, in the title or axis,
  not on every tick.
- Start bar axes at zero. Don't truncate axes to exaggerate change.

## Dashboard layout

- **Summary row first:** a row of stat tiles across the top, each with a label, a big number (`display-lg` or
  `heading-lg` in `data` style), a one-line context such as "vs last 30 days", and a link to the detail view. This
  is the at-a-glance layer.
- **Then detail sections:** each metric area gets a titled section with its charts. Collapse secondary sections
  behind an accordion when the page is long.
- **Show exceptions first.** Don't fill the screen with all-green "everything is fine" tiles. Highlight what needs
  attention and summarize the rest.
- Each chart sits in a `surface` card with `radius-md` and a `border` hairline. Its title states the metric and
  period ("Requests by region — last 30 days").
- Every chart needs an accessible name and a text alternative: a summary sentence, or a data table toggle.
- Deltas show direction three ways: arrow or sign, color, and the word or number. Never color alone.

## Tables

- Right-align numbers, and set them in tabular figures (IBM Plex Mono already is).
- Bottom-align header labels and top-align multi-line cells.
- Sticky headers on long tables. Zebra striping is not needed: use `border` row dividers.
- Wide tables scroll horizontally inside their own container, never the page.

## Loading and empty states

- Use skeleton blocks in `surface` and `border` for charts that take longer than about 300ms. Don't use spinners on
  every tile.
- An empty state says why it's empty and what to do next ("No data for this period — change the date range").
