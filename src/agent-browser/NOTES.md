## Requirements

A Debian or Ubuntu base image with `curl`, and a Chrome or Chromium for the CLI to drive — see
[The browser](#the-browser).

```json
"features": {
    "ghcr.io/orianna-ai/devcontainer-features/agent-browser:1": {}
}
```

No node. agent-browser is published to npm, but what npm ships is a Rust binary per platform, so —
like the grok feature and unlike the playwright and typescript-language-server ones — this feature
needs no node runtime and installs nothing into a node version's global root.

## Where it installs

The binary is copied to `/usr/local/share/agent-browser/bin/agent-browser` and symlinked to
`/usr/local/bin/agent-browser`, the same shared-prefix shape the other features use: one root-owned
copy, readable and executable by every user, writable by none of them.

The published package is the source rather than the matching GitHub release asset, which carries
the binary alone. The package holds every platform's binary *and* the bundled skills, so one
download answers both halves of the install; only this platform's binary and `skill-data` are
unpacked, and the rest of the tarball is discarded with the staging directory.

## Skills

`agent-browser skills get core --full` is how the CLI documents itself to an agent, and the skills
it serves are version-matched to the binary. They are not compiled in: they ship beside the binary
as `skill-data/`, and the lookup that finds them expects the npm package layout, which lifting the
binary into a shared prefix breaks. `AGENT_BROWSER_SKILLS_DIR` is therefore set through
`containerEnv` to the installed copy at `/usr/local/share/agent-browser/skill-data`.

`sudo` drops `containerEnv`, so `sudo agent-browser skills ...` would report no skills directory;
run the CLI as the remote user.

The package also ships one unrelated file — `skills/agent-browser/SKILL.md`, an agent skill in the
frontmatter format Claude Code, Codex, Grok and Antigravity all read — and it is installed
alongside at `/usr/local/share/agent-browser/skills`. That single file is the whole of upstream's
`skills/` tree, against 26 under `skill-data/`, because it is a discovery stub rather than a
manual: it tells an agent to run `agent-browser skills get core` before anything else, so the
guidance it hands over comes from the installed binary and stays matched to it. Being a pointer is
also what makes it stable enough to copy — there is nothing in it for a release to invalidate.

Nothing reads that copy automatically. It is there for whatever assembles agent plugin bundles to
copy out of, so a bundle carries upstream's stub byte for byte instead of a hand-written
paraphrase that drifts. `agent-browser` has no `install --skills` subcommand to generate one, which
is why the image carries it.

## The browser

This feature installs the CLI, not a browser. agent-browser looks for one at run time in its own
cache, among system Chrome installations, and in the Puppeteer and Playwright browser caches — the
last of which it locates through `PLAYWRIGHT_BROWSERS_PATH`.

So pairing it with this repository's playwright feature is enough, and is what the orianna
devcontainer does: that feature downloads a browser and exports the variable, and agent-browser
finds it with nothing configured. Which build that is — playwright ships releases that call
themselves "Chromium" and releases that call themselves "Google Chrome for Testing" — makes no
difference to the discovery.

```json
"features": {
    "ghcr.io/orianna-ai/devcontainer-features/playwright:1": {},
    "ghcr.io/orianna-ai/devcontainer-features/agent-browser:1": {}
}
```

Without it, `agent-browser doctor` reports no Chrome binary and `agent-browser install` downloads
Chrome for Testing into the running container. That download is deliberately not done at build
time. It would land in root's home, where the remote user cannot read it; it would duplicate a
browser the image already has; and upstream publishes no Linux ARM64 build of Chrome for Testing,
so on arm64 the playwright pairing is the only one of the two that works at all.

## Version pinning

`version` accepts an exact `X.Y.Z`, which freezes the CLI into the image digest. The default,
`latest`, resolves the newest published release at *image build* time — so it is still fixed for
the life of the image, and moves only when the image is rebuilt. That is the point of installing it
here rather than at container start: every container from a given image runs a known version
instead of whatever was newest when it happened to boot.

Because the skills come out of the same tarball as the binary, a pinned CLI serves the skills that
were written for it.

## Authentication

Nothing is authenticated at build time and nothing is read from the build environment. The CLI's
credential-bearing features — the `chat` command's `AI_GATEWAY_API_KEY`, the cloud browser
providers' keys, the auth vault's `AGENT_BROWSER_ENCRYPTION_KEY` — are all read at run time, so
none of them can be baked into an image layer.
