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

## Node versions

The CLI is installed under its own prefix, `/usr/local/share/playwright-cli`, and symlinked to
`/usr/local/bin/playwright-cli`. It is deliberately not a plain `npm install --global`: the node
feature installs node through nvm, whose global root is one directory per node version
(`$NVM_DIR/versions/node/<version>/lib/node_modules`), with `$NVM_DIR/current/bin` on `PATH`. A
`npm install --global` there belongs to whichever version was active at build time, so `nvm install`
or `nvm use` repoints `current` and `playwright-cli` drops off `PATH` for the whole container —
not just the shell that switched.

Switch node freely; one copy of the CLI stays reachable, and it runs on whatever node is active
(the package needs node 18 or newer). `/usr/local/bin` is also on `sudo`'s `secure_path`, so
`sudo playwright-cli` resolves too.

## Browsers

Chromium only, plus the headless shell and ffmpeg that come with it. Firefox and WebKit are not
downloaded.

They live in `/usr/local/share/ms-playwright` rather than Playwright's default `$HOME/.cache`, and
`PLAYWRIGHT_BROWSERS_PATH` is set through `containerEnv` to match. Nothing to configure, and it
keeps working when `HOME` is replaced at run time.

`PLAYWRIGHT_MCP_BROWSER=chromium` is set for the same reason. Left alone, `playwright-cli` opens the
branded `chrome` channel and looks for it at `/opt/google/chrome/chrome`, which nothing installs —
so `playwright-cli open` would fail with *"Chromium distribution 'chrome' is not found"* despite a
perfectly good Chromium sitting in the image. Callers can still override it per command with
`--browser`.
