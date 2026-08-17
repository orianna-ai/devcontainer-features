## Requirements

Select the node feature alongside this one. The install uses `npm` and exits with an explicit error
when it cannot find it — it never installs node for you, so your own version pin stays intact.

```json
"features": {
    "ghcr.io/devcontainers/features/node:2": {},
    "ghcr.io/orianna-ai/devcontainer-features/typescript-language-server:1": {}
}
```

The server is what LSP clients spawn as `typescript-language-server --stdio` — editors, and
Claude Code's TypeScript LSP plugin, need only this binary on `PATH`.

## Node versions

The server is installed under its own prefix, `/usr/local/share/typescript-language-server`, and
symlinked to `/usr/local/bin/typescript-language-server`. It is deliberately not a plain
`npm install --global`: the node feature installs node through nvm, whose global root is one
directory per node version (`$NVM_DIR/versions/node/<version>/lib/node_modules`), with
`$NVM_DIR/current/bin` on `PATH`. A `npm install --global` there belongs to whichever version was
active at build time, so `nvm install` or `nvm use` repoints `current` and
`typescript-language-server` drops off `PATH` for the whole container — not just the shell that
switched.

Switch node freely; one copy of the server stays reachable, and it runs on whatever node is active
(the package needs node 20 or newer). The install passes `--engine-strict` to npm, so building
against a node too old for the packages fails the image build with npm's explicit engine error
instead of producing a server that cannot start.

The install stays root-owned and read-only to the remote user. One copy backs every node version,
so no single user should be able to rewrite what the others execute.

Like the playwright feature, it resolves node from the caller's `PATH`, so `sudo` — which replaces
`PATH` with `secure_path` — is unsupported; run the server as the remote user.

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

Only `typescript-language-server` is symlinked into `/usr/local/bin`. The fallback's `tsc` and
`tsserver` stay private to the prefix rather than shadowing whatever the active node version or the
workspace provides.
