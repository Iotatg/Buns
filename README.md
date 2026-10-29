# Buns

A small, stateful AI-coworker workspace written in the **Bun language**. Buns is a from-scratch study of [OpenDots](https://github.com/CopilotKit/OpenDots): persistent coworkers, visible runs, human approval gates, a document library, and a computer view that follows each tool call.

The entire application is `.bun`, HTML, CSS, and vanilla JavaScript. There is **no framework, bundler, package install, database, or JavaScript runtime** in the server.

![Buns Today](docs/today.png)

## What works

- **Today** collects decisions, active runs, recent work, and spaces in one place.
- **Five coworkers** have persistent threads and different planning defaults.
- **Five playbooks** cover research, finance, communications, engineering, and operations.
- **Visible execution** reveals each run step, its tool, duration, and generated computer screen.
- **Real approval gates** stop risky steps. Approving applies the effect; refusing records a skip. A finished run cannot be decided twice.
- **Spaces and pages** include search, grid/list views, nested pages, Markdown rendering, page creation, and revision-checked autosave.
- **Responsive UI** works at desktop and phone widths. The computer becomes a drawer on smaller screens.
- **Persistent state** lives in one JSON document behind a mutex.

![A run waiting for approval](docs/coworker.png)

## Run it

### 1. Get the Bun-language runtime

Clone [Iotatg/Bun](https://github.com/Iotatg/Bun) next to this repository, or use any checkout and set `BUN_LANG_HOME` to the directory containing the `bun` Python package and `lib/bun` standard library.

```sh
git clone https://github.com/Iotatg/Bun.git ../Bun
cd buns
./bin/buns app.bun
```

For an existing checkout:

```sh
BUN_LANG_HOME=/path/to/Bun/bun ./bin/buns app.bun
```

Open `http://127.0.0.1:8801`. The first start seeds the Aurelia demonstration workspace.

### Configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `PORT` | `8801` | HTTP listen port |
| `BUNS_STATE` | `data/state.json` | Workspace JSON file |
| `BUN_LANG_HOME` | `vendor/` | Bun-language runtime location |

Delete the state file and restart to restore the seed. Do not expose this build directly to untrusted users: it has no authentication.

## Try the core loop

1. Open **Post** from the coworker rail.
2. Inspect the three-step run and the computer panel.
3. Choose **Refuse** or **Approve and continue** on the `mail.send` gate.
4. Ask Scout: `Brief me on freight costs` and watch a new run play.
5. Open **Spaces**, create a page, and edit it. Saves carry a revision; stale writes return `409` instead of overwriting another edit.

## Verify

```sh
./bin/buns check app.bun
sh scripts/smoke.sh
```

The smoke suite starts an isolated server on port `8802` with a temporary state file. It covers routing, assets, errors, message/run creation, decision replay protection, page creation, revision conflicts, and saving: **31 assertions**.

`scripts/test_engine.bun` exercises the planner and run engine directly.

## Routes

| Route | Purpose |
| --- | --- |
| `/` | Today, open gates, active and recent work |
| `/dots/:id` | Coworker thread, runs, approval gates, computer |
| `/spaces` | Space and page library |
| `/spaces/:id` | One space and its documents |
| `/spaces/:id/p/:page` | Markdown page and editor |
| `/search?q=…` | Workspace search |
| `/about` | Exact capabilities and limitations |
| `/health` | JSON health check |

API: `POST /api/messages`, `POST /api/runs/:id/decide`, `POST /api/pages`, and `PATCH /api/pages/:id`.

## Source map

```text
app.bun             router, JSON API, static assets
src/http.bun        raw-socket HTTP/1.1, keep-alive, chunked responses
src/store.bun       state, clock, ids, escaping, text helpers
src/seed.bun        Aurelia workspace and realistic source material
src/agent.bun       planner, five playbooks, tools, gates, effects
src/ui.bun          shell, icons, Markdown renderer, shared components
src/views.bun       pages, run cards, generated computer screens
assets/app.css      visual system and responsive layout
assets/app.js       playback, decisions, composer, library, autosave
scripts/smoke.sh    isolated end-to-end assertions
docs/               desktop and mobile screenshots
```

## Honest boundaries

This is a working product study, not a connected production agent:

- The planner is deterministic; **no LLM call is made**.
- Computer screens are generated from actual workspace state; **no real browser is automated**.
- Mail, pull requests, and calendar effects update local JSON; **no external service is contacted**.
- There is one local workspace and no authentication.
- A crash during the single JSON write can damage state; keep backups if the data matters.

OpenDots additionally implements areas such as scheduled activity, memories, voice, real computer control, and integrations. Those are future work here, not hidden stubs.

## Research and design

OpenDots was studied at commit `8091324`. [rea](https://github.com/morluto/rea) was used as a lens for evidence-based application analysis: trace interface elements to routes and behavior, and distinguish observed behavior from assumptions. The visual rules and anti-pattern checks come from [impeccable](https://github.com/pbakaus/impeccable).

See [DESIGN.md](DESIGN.md) for the design reasoning and architecture decisions.

## License

MIT for this project. OpenDots and impeccable remain under their respective licenses; no OpenDots application code is copied into Buns.
