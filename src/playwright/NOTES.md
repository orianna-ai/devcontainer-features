## Requirements

Select the node feature alongside this one. The install uses `npm` and exits with an explicit error
when it cannot find it — it never installs node for you, so your own version pin stays intact.

```json
"features": {
    "ghcr.io/devcontainers/features/node:2": {},
    "ghcr.io/orianna-ai/devcontainer-features/playwright:1": {}
}
```

Debian and Ubuntu only. Playwright installs Chromium's shared libraries with apt and has no
equivalent for other package managers.

## Browsers

Chromium only, plus the headless shell and ffmpeg that come with it. Firefox and WebKit are not
downloaded.

They live in `/usr/local/share/ms-playwright` rather than Playwright's default `$HOME/.cache`, and
`PLAYWRIGHT_BROWSERS_PATH` is set through `containerEnv` to match. Nothing to configure, and it
keeps working when `HOME` is replaced at run time.
