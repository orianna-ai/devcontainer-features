## Requirements

Select the node feature too — this one installs `@playwright/cli` with `npm` and exits with an
explicit error when `npm` is missing.

```json
"features": {
    "ghcr.io/devcontainers/features/node:2": {},
    "ghcr.io/orianna-ai/devcontainer-features/playwright:1": {}
}
```

Node is in `installsAfter` rather than `dependsOn` on purpose. Features dedupe only when their id
*and* options match exactly, so a `dependsOn` entry would install a second copy of the node feature
for anyone who already pins their own version, and whichever copy ran last would win the nvm
default.

Debian and Ubuntu only. Playwright installs Chromium's shared libraries with apt and has no
equivalent for other package managers, so the feature fails early on anything else.

## Browsers path

Browsers land in `/usr/local/share/ms-playwright` rather than Playwright's default `$HOME/.cache`,
because a sandbox may point `HOME` at a per-pod volume — anything baked into the image's home
directory is invisible there. `PLAYWRIGHT_BROWSERS_PATH` is set through `containerEnv`, so the
install and every later run agree on that location with no further setup.
