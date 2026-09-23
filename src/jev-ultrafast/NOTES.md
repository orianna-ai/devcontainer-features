## Requirements

A Debian or Ubuntu base image with `curl` and `git`, and a Chrome or Chromium for the agent to
drive — see [The browser](#the-browser).

```json
"features": {
    "ghcr.io/orianna-ai/devcontainer-features/playwright:1": {},
    "ghcr.io/orianna-ai/devcontainer-features/jev-ultrafast:1": {}
}
```

## What it is

[Jev Ultrafast](https://github.com/browser-use/jev-ultrafast) is a browser agent from Browser Use.
Each step reads the page into a numbered table of controls. One request to
[TypeSafe's Jev](https://docs.typesafe.ai/introduction) then picks both the operation (`CLICK`,
`TYPE_TEXT`, `SELECT`, `SCROLL_*`, `WAIT`, `DONE`, `BLOCKED`) and its target. A small text model
runs only when a field needs typing. The loop never takes a screenshot, so a goal finishes in
seconds rather than the tens of seconds a screenshot-driven agent takes.

## The command

Upstream ships a library and a local inspector UI, but no command that takes a goal and returns a
result. This feature adds one, `jev-ultrafast`:

```bash
jev-ultrafast --url https://en.wikipedia.org --goal 'Open the article about Gödel'
```

Progress goes to stderr, one line per decision. When the run stops, one JSON object goes to stdout:
`status` (`done` or `blocked`), `error`, `elapsed_ms`, the final `url`, `title` and visible `text`,
and the `actions` taken. The exit code is 0 only for `done`. A `done` is Jev's own verdict, so read
the final page before relying on it.

`--jsonl` streams the run instead: each decision is written to stdout as one
`{"event": "step", ...}` line, and the result follows as `{"event": "result", ...}`. SIGTERM stops
the run and the browser it launched.

## The browser

Each run launches a fresh headless Chromium with a throwaway profile and stops it on exit. It finds
the browser in the Playwright cache (`PLAYWRIGHT_BROWSERS_PATH`), then on `PATH`;
`JEV_ULTRAFAST_CHROME` overrides both. If `BU_CDP_URL` or `BU_CDP_WS` is set, the run attaches to
that browser instead and launches nothing.

Chromium keeps its sandbox wherever it can. As root, or in a container without user namespaces
(where a sandboxed launch exits at once), it relaunches with `--no-sandbox` and prints a warning
to stderr. `JEV_ULTRAFAST_NO_SANDBOX=1` skips the sandboxed attempt.

Browser Harness keeps its daemon state in a per-run temporary directory, and its telemetry is off
unless `BH_TELEMETRY` says otherwise. Concurrent runs therefore never share a daemon or a browser.

## Where it installs

Upstream publishes no releases or PyPI package, so `version` is a git ref and defaults to a pinned
commit. The package goes into a virtualenv at `/usr/local/share/jev-ultrafast/venv`. Its private
uv-managed interpreter sits beside it and does not depend on the image's Python. The command is
symlinked to `/usr/local/bin/jev-ultrafast`. Everything is root-owned and read-only to other users.
The uv that builds the install comes from a release archive checked against a pinned SHA-256, and is
discarded afterwards.

## Authentication

Nothing is read at build time. At run time the command needs:

| Variable | Used for |
| --- | --- |
| `TYPESAFE_API_KEY` | Every decision. Required. |
| `TEXT_MODEL_API_KEY` | Writing text when a field needs typing. |
| `TEXT_MODEL_BASE_URL` | An OpenAI-compatible endpoint for the text model. |
| `TEXT_MODEL` | The text model id, such as `inception/mercury-2.5`. |
| `TEXT_MODEL_REASONING` | `none` turns reasoning off. |
