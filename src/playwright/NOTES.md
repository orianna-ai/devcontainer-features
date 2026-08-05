## Requirements

Node has to be selected too — the feature installs `@playwright/cli` with `npm`, and it fails with
an explicit error when `npm` is not on `PATH`.

```json
"features": {
    "ghcr.io/devcontainers/features/node:2": {},
    "ghcr.io/orianna-ai/devcontainer-features/playwright:1": {}
}
```

Node is listed in `installsAfter` rather than `dependsOn` so that consumers keep control of their
own Node version. The spec only deduplicates Features whose id *and* options match exactly, so a
`dependsOn` entry would install a second, separately versioned copy of the Node feature for anyone
who already pins one, and whichever copy ran last would win the nvm default.

Debian and Ubuntu base images only. Playwright installs Chromium's shared libraries with apt and has
no equivalent for other package managers, so the feature fails early on anything else.

## Browsers path

Browsers land in `/usr/local/share/ms-playwright` rather than Playwright's default `$HOME/.cache`,
because a sandbox may point `HOME` at a per-pod volume — anything baked into the image's home
directory is invisible there. `PLAYWRIGHT_BROWSERS_PATH` is set through `containerEnv`, so the
install and every later run agree on that location without any further setup.
