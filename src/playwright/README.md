
# Playwright (playwright)

Installs the Playwright CLI and Chromium

## Example Usage

```json
"features": {
    "ghcr.io/orianna-ai/devcontainer-features/playwright:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Version of the @playwright/cli package to install. | string | latest |

## Requirements

The feature installs `@playwright/cli` with `npm`, so the node feature has to be selected alongside
it. The install exits with an explicit error when `npm` is missing rather than half-succeeding.

```json
"features": {
    "ghcr.io/devcontainers/features/node:2": {},
    "ghcr.io/orianna-ai/devcontainer-features/playwright:1": {}
}
```

Node is in `installsAfter` rather than `dependsOn` deliberately: features dedupe only when their id
*and* options match exactly, so a `dependsOn` entry would install a second copy of the node feature
for anyone who pins their own version, and whichever copy ran last would win the nvm default.

Debian and Ubuntu only. Playwright installs Chromium's shared libraries with apt and has no
equivalent for other package managers, so the install fails early on anything else.

## Browsers

Chromium only, alongside the headless shell and ffmpeg that Playwright pulls with it. Firefox and
WebKit are not downloaded.

They land in `/usr/local/share/ms-playwright` rather than Playwright's default `$HOME/.cache`,
because a sandbox may point `HOME` at a per-pod volume, where anything baked into the image's home
directory is invisible. `PLAYWRIGHT_BROWSERS_PATH` is set through `containerEnv`, so the install and
every later run agree on that location with no further setup.

The directory is left readable and traversable by the remote user, and the global module tree keeps
the ownership the node feature gave it, so installing more global packages at run time still works.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
