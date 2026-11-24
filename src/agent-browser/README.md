# agent-browser (agent-browser)

Installs the agent-browser CLI, a browser automation CLI for AI agents, as a standalone binary with its bundled skills.

## Example Usage

```json
"features": {
    "ghcr.io/orianna-ai/devcontainer-features/agent-browser:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Version of the agent-browser package to install, as X.Y.Z, or latest for the newest published release. | string | latest |

## Requirements

A Debian or Ubuntu base image with `curl`, on `amd64` or `arm64`, and a Chrome or Chromium for the
CLI to drive (see [The browser](#the-browser)). agent-browser is published to npm, but as a Rust
binary, so this feature needs no node.

## Where it installs

The binary goes to `/usr/local/share/agent-browser/bin/agent-browser` and is symlinked to
`/usr/local/bin/agent-browser`: one root-owned copy, executable by every user and writable by none.

Both halves of the install come from npm at the same version. The `agent-browser` package holds the
bundled skills. The binary ships in `@agent-browser/cli-linux-<arch>-gnu` from 0.43.0, and inside
`agent-browser` itself before that, so the feature looks there first.

## Skills

`agent-browser skills get core --full` is how the CLI documents itself to an agent. The skills ship
beside the binary as `skill-data/`, and the CLI only finds them on its own in the npm package
layout. The feature therefore sets `AGENT_BROWSER_SKILLS_DIR` through `containerEnv` to
`/usr/local/share/agent-browser/skill-data`.

`sudo` drops `containerEnv`, so run the CLI as the remote user.

## The browser

This feature installs the CLI, not a browser. At run time agent-browser looks in its own cache,
among system Chrome installations, and in the Puppeteer and Playwright caches, finding the last
through `PLAYWRIGHT_BROWSERS_PATH`. Pairing it with this repository's playwright feature is
therefore enough:

```json
"features": {
    "ghcr.io/orianna-ai/devcontainer-features/playwright:1": {},
    "ghcr.io/orianna-ai/devcontainer-features/agent-browser:1": {}
}
```

Without a browser, `agent-browser install` downloads Chrome for Testing into the running container.
The feature doesn't do that at build time: it would land in root's home, where the remote user
can't read it, and Chrome for Testing has no Linux ARM64 build.

## Version pinning

`version` accepts an exact `X.Y.Z`, which freezes the CLI into the image digest. The default,
`latest`, resolves the newest release at *image build* time, so it is still fixed for the life of
the image and moves only when the image is rebuilt.

## Authentication

Nothing is authenticated at build time. The CLI reads its keys, such as `AI_GATEWAY_API_KEY` and
`AGENT_BROWSER_ENCRYPTION_KEY`, at run time, so none can be baked into an image layer.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
