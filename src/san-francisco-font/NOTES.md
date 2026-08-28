## Requirements

A Debian or Ubuntu base image with `curl`. Everything else the build needs — `fontconfig`, and a
7-Zip to open Apple's disk images — is installed by the feature, and the archiver is purged again
afterwards if the feature is what pulled it in.

```json
"features": {
    "ghcr.io/orianna-ai/devcontainer-features/san-francisco-font:1": {}
}
```

Nothing depends on the playwright feature, and the order the two install in does not matter. This
one only changes what fontconfig answers; every process that reads fonts through fontconfig — the
Chromium playwright drives included — picks the change up at its next start.

## Where it installs

The fonts go to `/usr/local/share/fonts/san-francisco`, root-owned and read-only to the remote
user, the same shape the other features in this repository use. The fontconfig rules are written to
`/etc/fonts/conf.avail/59-san-francisco.conf` and symlinked into `/etc/fonts/conf.d`, so removing
the symlink turns the substitution off without uninstalling the fonts.

## What is downloaded

Apple publishes each family as a disk image holding an installer package, whose payload is a
gzipped cpio archive of the fonts. The feature unpacks its way down to the fonts and keeps only
what it needs: `SF-Pro.ttf` and `SF-Pro-Italic.ttf`, plus the twelve SF Mono faces when `mono` is
on.

How many layers that takes depends on the 7-Zip build, so it is not hardcoded. 7-Zip 23 unwraps the
payload's gzip and cpio together while extracting the installer package, leaving three layers;
7-Zip 26 — the version on Ubuntu 26.04 — stops at the gzip stream and needs a fourth pass. The
feature extracts a layer at a time, stopping at the first that contains font files, so both behave
the same. Nothing is filtered on the way down either: a filter that matches nothing at a layer
extracts nothing and still succeeds, which is silent breakage the moment the nesting shifts.

The two SF Pro files are the *variable* fonts, not the 44 static instances sitting beside them in
the same download. One pair of files carries every weight from Ultralight to Black and every width
from Compressed to Expanded, and its optical size axis is what makes text pick up the Display
drawing at headline sizes and the Text drawing at body sizes the way it does on macOS. It is also
40MB against 270MB for the same coverage. The build still downloads the whole 210MB image to get
them; only the image layer is small.

Apple serves those downloads from a stable URL with no version in it and no published checksum, so
there is nothing to pin. A rebuild picks up whatever Apple is shipping that day, and the feature
fails loudly — rather than installing a partial set — if a file it expects is no longer in the
download.

These are Apple's fonts under Apple's licence, which allows use in designing and developing
software but not redistribution. The feature fetches them from Apple at build time for that reason;
do not vendor the files into a repository or publish an image layer containing them outside the
team.

## How the substitution works

The fonts keep their real family names — `SF Pro` and `SF Mono` — and the rules say which requests
those names answer. Nothing is renamed, so `fc-list` and any code asking for a font by name still
see the truth.

Two mechanisms, for two different situations:

- Names nothing else claims — `system-ui`, `-apple-system`, `BlinkMacSystemFont`, `.SF NS`,
  `SF Pro Text`, `ui-monospace`, `Menlo`, and the `sans-serif` and `monospace` generics — get a
  weakly bound preference. A weak binding is what lets a page that names a font the image actually
  has still get that font.
- `Arial` and `Helvetica` already resolve, to Liberation Sans, through the strongly bound aliases
  in `30-metric-aliases.conf`. A weak preference loses to those, so those names take the head of
  the family list with a binding of matching strength instead.

The file is numbered 59 to land before `60-latin.conf`. Both files put their preference in front of
the generic name rather than at the head of the list, so between two preferences for `sans-serif`
it is the one read *first* that ends up in front — the opposite of the usual "last config wins".

## Why `webSafeSans` is on by default

Chromium does not ask fontconfig for `sans-serif`. It resolves the CSS generic against its own
default font preference, which on Linux is the literal string `Arial`, and asks fontconfig for
that. So aliasing the generic alone changes nothing a page can see: with `webSafeSans` off,
`fc-match sans-serif` reports SF Pro while Chromium still renders Liberation Sans.

Turning it on routes `Arial`, `Helvetica`, `Helvetica Neue`, `Segoe UI` and `Roboto` to SF Pro,
which is what actually makes `font-family: sans-serif` render as San Francisco. The cost is that a
page explicitly asking for Arial gets San Francisco too. That is the trade: there is no signal in
what reaches fontconfig that distinguishes Chromium's generic from a page's deliberate `Arial`.

`monospace` needs no equivalent, because Chromium's default fixed font is `Monospace`, which
fontconfig already treats as the generic.

## What is left alone

Serifs. `serif`, `Times New Roman` and `Georgia` still resolve to whatever the image had, as does
`Courier New`. A page that has no `font-family` at all also still renders a serif, because that
falls to Chromium's standard font — also `Times New Roman` — and this feature does not claim it.
Making San Francisco answer for a serif would break every page that asked for one deliberately.
