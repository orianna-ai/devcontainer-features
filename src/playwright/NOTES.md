## Requirements

None beyond the base image: the feature brings its own node, so it works with or without the node
feature, and nothing a workspace later does to the image's node can affect it.

```json
"features": {
    "ghcr.io/orianna-ai/devcontainer-features/playwright:1": {}
}
```

Debian and Ubuntu only. Playwright installs Chromium's shared libraries with apt and has no
equivalent for other package managers.

## Node versions

The CLI is installed under its own prefix, `/usr/local/share/playwright-cli`, and runs on a private
node runtime at `/usr/local/share/node-runtime/v<nodeVersion>` (fetched from nodejs.org and
checksum-verified at build time). `/usr/local/bin/playwright-cli` is a wrapper that execs that
runtime by absolute path — deliberately not a symlink to the npm shim, whose `#!/usr/bin/env node`
shebang would resolve the interpreter from the caller's `PATH` at spawn time.

That makes the CLI independent of the container's node end to end. `nvm install` / `nvm use`
repointing nvm's `current` symlink, `nvm uninstall` of the build-time version, switching to fnm or
mise, or deleting the nvm tree outright: none of it can break the CLI, because nothing it runs is
looked up through `PATH` or nvm. Playwright spawns its own child processes through
`process.execPath`, so they stay on the private runtime too.

Sibling features of this repository that pin the same `nodeVersion` share one runtime copy.

The install stays root-owned and read-only to the remote user — the runtime included, so no
workspace user can rewrite the interpreter others execute.

The CLI no longer needs `PATH` to find node, but it still reads `PLAYWRIGHT_BROWSERS_PATH` and
`PLAYWRIGHT_MCP_BROWSER` from `containerEnv`. `sudo` drops `containerEnv`, so `sudo playwright-cli`
stays unsupported; run the CLI as the remote user.

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
