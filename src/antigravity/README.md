# Antigravity CLI (antigravity)

Installs the Antigravity CLI from Google.

## Example Usage

```json
"features": {
    "ghcr.io/orianna-ai/devcontainer-features/antigravity:1": {}
}
```

## Requirements

None beyond a Debian or Ubuntu base image with `curl`. The CLI is a single static binary, so —
unlike the playwright and typescript-language-server features — this one needs no node feature
alongside it and installs nothing into a node version's global root. It is a large binary (a little
over 200 MB), which lands as one layer in whatever image installs it.

```json
"features": {
    "ghcr.io/orianna-ai/devcontainer-features/antigravity:1": {}
}
```

## Where it installs

The binary is copied to `/usr/local/share/antigravity/bin/agy` and symlinked to
`/usr/local/bin/agy`, the same shared-prefix shape the other features use: one root-owned copy,
readable and executable by every user, writable by none of them.

Upstream's installer is run to fetch the binary rather than reimplementing its platform detection
and checksum verification, but it is not left to place the result. Its default target is
`$HOME/.local/bin`, so an install run as root during a build puts the binary under `/root` —
reachable while building, unreadable to the remote user afterwards. `--dir` moves the binary, but
two things still follow `HOME`: the download is staged through `$HOME/.cache/antigravity`, and the
installer's last step hands off to `agy install`, which appends the install directory to the shell
profiles it finds in `$HOME`. The feature stages a `HOME`, lets both of those land inside it,
copies the binary into the shared prefix, and deletes the staging directory. The symlink is what
puts the CLI on `PATH`, so nothing has to be added to a profile.

## Authentication

Nothing is authenticated at build time. The installer's only network calls are to the public
release manifest and the release archive it names; it reads no credential from the environment it
inherits, so none can be baked into an image layer.

At run time the CLI takes either a cached interactive login or an API key. The key path is the one
a headless container wants: `modelProvider` set to `gemini` in
`~/.gemini/antigravity-cli/settings.json`, with `GEMINI_API_KEY` exported. Both are configured by
whatever drives the CLI, not here.

## Version pinning

Upstream's installer takes no version argument — it always resolves the newest build from its
release manifest — so unlike the grok feature there is no `version` option to expose. The version
is nonetheless fixed for the life of the image: it resolves at *image build* time and moves only
when the image is rebuilt. That is the point of installing it here rather than at container start.

The CLI also self-updates in the background during normal runs, which would undo that. Installing
it root-owned and read-only to the remote user is what holds a container on the version its image
was built with; a read-only binary still runs normally, and the updater has no writable target to
replace.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
