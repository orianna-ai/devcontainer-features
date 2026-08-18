
# TypeScript Language Server (typescript-language-server)

Installs the TypeScript language server for LSP clients on a private node runtime, independent of any node in the image.

## Example Usage

```json
"features": {
    "ghcr.io/orianna-ai/devcontainer-features/typescript-language-server:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| nodeVersion | Version of the private node runtime that runs the server, as X.Y.Z. Features pinning the same version share one runtime copy. | string | 24.18.0 |
| typescriptVersion | Version of the typescript package that backs the server when the workspace has none. TypeScript 7+ is the native rewrite without tsserver and cannot back this server. | string | 6 |
| version | Version of the typescript-language-server package to install. | string | latest |

## Requirements

None beyond the base image: the feature brings its own node, so it works with or without the node
feature, and nothing a workspace later does to the image's node can affect it.

```json
"features": {
    "ghcr.io/orianna-ai/devcontainer-features/typescript-language-server:1": {}
}
```

The server is what LSP clients spawn as `typescript-language-server --stdio` — editors, and
Claude Code's TypeScript LSP plugin, need only this binary on `PATH`.

## Node versions

The server is installed under its own prefix, `/usr/local/share/typescript-language-server`, and
runs on a private node runtime at `/usr/local/share/node-runtime/v<nodeVersion>` (fetched from
nodejs.org and checksum-verified at build time). `/usr/local/bin/typescript-language-server` is a
wrapper that execs that runtime by absolute path — deliberately not a symlink to the npm shim,
whose `#!/usr/bin/env node` shebang would resolve the interpreter from the caller's `PATH` at
spawn time.

That makes the server independent of the container's node end to end. `nvm install` / `nvm use`
repointing nvm's `current` symlink, `nvm uninstall` of the build-time version, switching to fnm or
mise, or deleting the nvm tree outright: none of it can break the server, because nothing it runs
is looked up through `PATH` or nvm. tsserver is spawned through `fork()`, which reuses the running
interpreter, so it stays on the private runtime too.

Sibling features of this repository that pin the same `nodeVersion` share one runtime copy.

The install passes `--engine-strict` to npm, so building against a runtime too old for the packages
fails the image build with npm's explicit engine error instead of producing a server that cannot
start.

The install stays root-owned and read-only to the remote user — the runtime included, so no
workspace user can rewrite the interpreter others execute.

## TypeScript ("tsserver")

`typescript-language-server` does not bundle `typescript`: it drives the workspace's own
`node_modules/typescript` when there is one, and otherwise falls back to a `typescript` it can
resolve from its install tree. The feature installs one into the same prefix to be that fallback,
so the server initializes in a workspace with no `typescript` dependency. A workspace copy always
wins when present, keeping diagnostics on the project's pinned compiler.

The fallback defaults to major 6 rather than `latest`, and the install fails loudly on a version
that cannot work: the server runs `typescript/lib/tsserver.js`, which TypeScript ships only through
6.x — 7 is the native-compiler rewrite with no tsserver to run, and a server pointed at it dies on
initialize with *"Could not find a valid TypeScript installation"*. Pin `typescriptVersion`
anywhere in 5.x or 6.x freely.

Only `typescript-language-server` gets an entry point in `/usr/local/bin`. The fallback's `tsc` and
`tsserver` stay private to the prefix rather than shadowing whatever the active node version or the
workspace provides.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
