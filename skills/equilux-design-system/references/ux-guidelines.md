# UX guidelines

Brand-neutral interaction, layout and copy practice that Equilux UIs follow. The brand-specific look is in
`spec.md`. This file covers how things behave.

## Principles that change implementation

- **Back is the most important action.** Every screen and flow has a way out: Back, Cancel, Close or Skip. If leaving
  would lose work, keep the draft rather than trapping the user.
- **Assume mistakes.** Prefer undo, or a deferred commit ("Deleted · Undo"), over "Are you sure?" dialogs. Keep
  confirmation dialogs for actions that are destructive and can't be undone, and name the consequence in them.
  Never clear a form as a side effect.
- **Progressive disclosure.** Show a summary first and details on demand. Split crowded screens into a hub with
  focused sub-views instead of one long page of everything.
- **Show only what the user can act on.** Hide actions the user lacks permission for in this context, or disable
  them and explain why if they need to know the action exists.
- **Surface exceptions, not noise.** A healthy state is quiet. Don't list every passing item in green. Show what
  needs attention.
- **Let the computer format.** Accept input flexibly (phone numbers, dates, amounts) and format output from the
  user's locale and preferences. No text baked into images.
- **Persist user input.** Don't discard entered data on cancel, navigation or a failed submit. Don't interrupt a task
  the user started with an unrelated prompt.
- **Work on poor connections.** Show stale-but-available data marked as stale rather than a blank screen, and retry
  quietly.

## Copy and text presentation

- Use sentence case for headings, buttons, labels, menu items and links. Proper names keep their capitals.
- Lead with the key fact, and keep sentences short and plain. Avoid jargon unless the audience uses it.
- Button labels are verbs that say what happens ("Save changes", "Send invoice"), not "OK" or "Submit".
- When referring to UI in text, match its label exactly ("select **Save changes**").
- Left-align text and never justify it. Center only short, isolated items such as an empty-state message or a hero
  line.
- Emphasis: bold a few words at most, never whole paragraphs. All-caps only through the `label` token. Underline only
  links.
- Use an ellipsis (…) for in-progress states ("Saving…"). One-sentence titles and labels take no final period.

## Messages and notifications

Every error or exception message answers three questions in order: **What happened? What does it mean? What can I
do?** It has a short, specific title and at least one action, even if that action is only Dismiss. Don't blame the
user.

| Situation | Pattern |
| --- | --- |
| A field is invalid | An inline message under the field. The field's border and an icon change too, never color alone |
| A form submit fails | A banner at the top of the form summarizing the problems (linked to each field) **and** the inline messages |
| A page-level or system event | One banner docked at the top of the content area, persistent while scrolling |
| Brief confirmation of a user action | An inline confirmation near the action, or a banner that may auto-dismiss |
| Blocking (the user can't proceed) | A full-page state or modal with the way forward |

- Show one message at a time, with the highest priority first. Never stack banners or toasts.
- Errors never auto-dismiss. Success messages may, unless the user has to read them.
- Each message carries a status icon, a status word and color together.
- Announce dynamic messages to assistive technology (`role="status"` for polite updates, `role="alert"` for errors).

## Forms

- Every field has a visible label above it. A placeholder is never the label.
- Mark optional fields "(optional)" rather than starring the required ones, when most fields are required.
- Validate on blur or submit, not on every keystroke. Keep entered values when validation fails.
- Group related fields, keep forms in one column, and size inputs to their expected content.
- Use the right input type and `autocomplete` attribute (email, tel, postal code, one-time code).
- Choice controls: use radio buttons for up to about 5 options, a select or searchable list beyond that, and
  checkboxes for multiple selections. Use a toggle switch only for settings that take effect immediately.
- Search is a text field with a clear button. Show hint text only when it adds information.

## Navigation and structure

- Keep primary navigation in one consistent place on every screen. Every nav item has a text label; icons support
  the label but never replace it.
- Make the current location obvious: a selected nav state, plus a page title, plus breadcrumbs inside deep
  hierarchies.
- Keep the page title anchored while content scrolls when the page is long.
- Put overflow actions in a "More" menu rather than crowding the toolbar.

**Choosing a container:**

| Use a full page when | Use a drawer, side panel or popover when |
| --- | --- |
| The list has more than about 8 items and needs search | There are 2–8 options or a single decision |
| The flow is multi-step, or a create/edit form | It's a small edit that should keep the context visible |
| The task needs focus or a lot of content | The user needs to compare against what's behind it |

At narrow widths and on touch, prefer a drawer or full-screen list over a small dropdown.

**Actions:**

- Forward actions (Next, Save) sit on the right and backward actions (Back, Cancel) on the left, consistently.
- Put the primary action last in reading order within a button group. Use only one primary button per view.
- Actions that apply to a whole screen, table or multi-selection go in a sticky action bar at the bottom of the
  viewport. Leave scroll room so content is never hidden under it.
- Give multi-select lists select-all, select-none and a visible count of what's selected.

## Lists and tables

- Selectable rows show a hover state and a selected state, with a chevron when the row navigates.
- Use accordions to cut clutter. Decide the default open or closed state from how important the content is.
- Right-align numeric columns so magnitude scans. Top-align multi-line rows and bottom-align header labels.

## Loading, waiting and motion

| Wait | Feedback |
| --- | --- |
| < 100ms | None |
| 100–300ms | Usually none; a subtle state change on the control at most |
| 300ms–1s | A subtle indicator (button spinner, skeleton) |
| 1–10s | A clear loading state that names what's happening |
| > 10s | Progress, an estimate, or a way to continue in the background |

- Delay spinners by about 200–500ms so fast responses don't flash. Once shown, keep them up for at least about
  500ms.
- Waiting indicators loop, but success, warning and error states don't animate repeatedly.
- Use motion to explain a change (where something went, what opened). Never use it as decoration. Keep it short and
  respect `prefers-reduced-motion` by removing non-essential animation.

## Help

- Add contextual help only where it adds information that isn't already visible. Use an info icon beside the
  label, open the help on click (not hover only), and close it with Esc or a click outside.
- Don't add help icons to every cell or field just to be consistent.
