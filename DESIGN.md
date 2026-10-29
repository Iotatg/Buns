# Buns design

## Product thesis

Buns treats an AI coworker as a **durable working relationship**, not a disposable chat. The interface therefore keeps four things visible at once:

1. who is doing the work;
2. what plan is executing;
3. what the coworker is looking at;
4. where a human must make the decision.

The core loop is **ask → inspect the run → approve or refuse → keep the artifact**. Today is an operational summary, while each coworker owns the full thread and audit trail.

## What the source research changed

The second pass through the OpenDots source turned a study into an alignment. Three facts from the code drove the work: the client recognises exactly four views (`chat`, `tasks`, `memories`, `space`) plus `settings` and `schedule` dialogs; the server exposes `/api/state`, `/api/tasks` with `:id/actions` and `:id/schedule`, `/api/settings`, and `/api/memories`; and a task carries its schedule, its actions, and its computer steps in one object.

Buns now mirrors that surface view for view and endpoint for endpoint, while keeping its own implementation:

| OpenDots | Buns | Note |
| --- | --- | --- |
| Dots | **Buns** | Same idea, own name; `/buns/:id` with `/dots/:id` still resolving |
| `chat` view | Bun thread with composer and run playback | Unchanged from the first build |
| `tasks` view | `/tasks` ledger: waiting, in progress, scheduled, finished, activity | Backed by `GET /api/state`, `POST /api/tasks`, `GET /api/tasks/:id`, `POST /api/tasks/:id/actions` |
| Task schedules | `PUT /api/tasks/:id/schedule`, `DELETE /api/schedules/:id` | Cadence maths in `src/schedule.bun`; fires on read |
| `memories` view | `/memories` with full CRUD | `POST/PUT/DELETE /api/memories`; a finished task writes one automatically and the next plan recalls up to three as its first, visible step |
| `settings` dialog | `/settings` page + `PATCH /api/settings` | Integrations listed as **Not connected**, honestly |
| Human approvals | Gate state machine, approve/refuse/respond | `respond` is the OpenDots action for talking back mid-task |
| Spaces and pages | `/spaces` library | Unchanged |
| Voice, takeover, live integrations | Deliberately absent | Named in README and Settings, not stubbed |


OpenDots was cloned and read at commit `8091324`, especially `README.md`, `src/client/App.tsx`, `src/client/Chat.tsx`, and `src/client/PageDocument.tsx`. The confirmed source model includes Dots, Spaces, recent chats, human-in-the-loop cards, an embedded Computer view, scheduled activity, memories, and settings.

Buns adopts the durable Dot thread, document library, approval card, and Computer relationship. It deliberately differs in two ways:

- **Today** is a Buns-specific command center for decisions and recent work.
- **Run playback** makes the sequence and timing legible even though the local planner completes synchronously.

OpenDots features not modelled here—voice, real browser control and takeover, and live integrations—are listed as boundaries rather than implied by inactive controls.

rea was cloned at `1ef5918`. It is a reverse-engineering MCP/CLI, not an OpenDots dependency. Its useful discipline is evidence: connect UI claims to routes and implementation, record limitations, and never confuse a visible element with a working integration.

## Visual direction: the working sheet

The visual metaphor is an editorial working sheet beside a dark instrument panel.

- **Bone ground** (`#f5f4f0`) and warm paper cards keep the workspace quiet.
- **Espresso rail** (`#16140f`) provides a stable navigation landmark.
- **Persimmon** (`#c2410c`) is reserved for action and the current decision.
- **Newsreader** carries headlines, document prose, and run language because reading is the primary activity.
- **Instrument Sans** handles controls and navigation.
- **JetBrains Mono** identifies tools, revisions, timestamps, and other machine facts.

The Computer is the only large dark object in the content area. Its screens use their own light document surface, so mail and pages remain readable rather than becoming decorative terminal graphics.

Spacing follows a 4px base rhythm. Borders are thin and low-contrast; elevation is rare. Cards appear only for decisions, spaces, messages, and the composer—not around every section.

## Typography and accessibility

Body text starts at 15px with 1.6 line height. Document prose is 17px with a 66-character measure. Heading levels remain sequential. Generated Computer documents use styled paragraphs instead of skipping from the page heading to an `<h4>`.

Text and controls were checked in rendered pages. Muted colors on the dark rail and Computer were raised to readable contrast. Search placeholders use full-opacity muted ink. Focus receives a visible persimmon outline. Reduced-motion preferences disable playback animation.

Long prose uses `text-wrap: pretty` to reduce orphan words. Tables scroll inside their own container rather than widening the application.

## Responsive behavior

| Width | Behavior |
| --- | --- |
| Above 1280px | Full rail, content, and 404px Computer |
| 1080–1280px | Narrower Computer and content spacing |
| 900–1080px | Icon rail; document sidebars simplify |
| 680–900px | Computer becomes an overlay drawer |
| Below 680px | Rail becomes a horizontal coworker strip; single-column content |

The layout uses `minmax(0, 1fr)` and `min-width: 0` at grid boundaries. The Computer drawer closes with Escape. At 390px and 1440px, all six primary routes have zero document-level horizontal overflow.

## Application architecture

### Server

`src/http.bun` implements HTTP/1.1 over raw sockets, including keep-alive and chunked response bodies. `app.bun` owns routing and the small JSON API. HTML is assembled as escaped strings in Bun; there is no template engine.

### State

The workspace is one dictionary loaded from `data/state.json`. Mutations call `commit()`, which writes the document while holding a mutex. This is appropriate for a local demonstration, not a multi-user production store. The current language lacks a rename primitive, so the write is not claimed to be crash-atomic.

### Agent

`src/agent.bun` is explicit about its boundary: there is no model call. `plan()` classifies the goal into one of five playbooks and fills steps with real workspace records. Each step contains:

- tool name and human label;
- deterministic duration;
- pending, done, waiting, applied, or skipped state;
- risk flag and outcome detail;
- a structured `screen` dictionary.

`advance()` executes safe steps and stops at risk. `decide()` is the only path that applies a risky effect. This makes approval a state-machine rule rather than a visual suggestion.

### Computer

`screen_html()` turns each step's screen dictionary into HTML. The browser panel changes as playback moves through the run. It is not a screenshot, video, iframe, or claim of real web automation.

### Client

Vanilla JavaScript supplies progressive enhancement: composer submission, run playback, approval/refusal, Computer drawer, library filtering, page creation, and revision-checked autosave. The server remains the source of truth and returns `409` for stale page revisions and repeated decisions.

## Impeccable review

The six primary routes were checked with impeccable's rendered-browser detector. The final result is **0 primary anti-patterns and 0 advisories**. Earlier review corrected low contrast, an overused display font, skipped heading levels, gradient-based ruled filler, and orphan-prone prose.

Final functional verification:

- Bun syntax check passes.
- Smoke suite: **31 passed, 0 failed**.
- Six routes at 390px and 1440px: zero horizontal overflow and zero browser console errors.

## Deliberate non-goals

Authentication, multi-tenancy, external mail/calendar/GitHub writes, real browser sessions, voice, memories, and an LLM connection are outside this build. Adding a model should replace `plan()` without weakening the approval or persistence invariants.
