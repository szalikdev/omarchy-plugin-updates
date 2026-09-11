# omarchy-plugin-updates

An [Omarchy](https://omarchy.org/) shell plugin that tells you when one of
your other git-managed shell plugins has an update available.

Omarchy's built-in "Omarchy update" bar icon only tracks OS/pacman updates.
Third-party shell plugins installed with `omarchy plugin add` have no such
indicator — you only find out they're behind by running
`omarchy plugin update` yourself. This fills that gap.

## What it does

- Every 6 hours (or on demand), fetches each git-managed plugin under
  `~/.config/omarchy/plugins/` and compares local `HEAD` against the
  fetched `FETCH_HEAD`, without merging anything.
- Shows a bar icon only when at least one plugin is behind. Hovering lists
  which ones.
- Clicking opens a floating terminal running `omarchy plugin update`, which
  shows the diff and asks for confirmation before fast-forwarding.

Plugins that aren't git checkouts (e.g. ones you cloned from a built-in with
`omarchy plugin clone`) are skipped — there's nothing to fetch for those.

## Requirements

Just `git`, `bash`, and coreutils' `timeout` — all already present on any
Omarchy install, since `omarchy plugin update` depends on `git` too.

## Install

```
omarchy plugin add https://github.com/szalikdev/omarchy-plugin-updates.git --enable
```

## Remove

```
omarchy plugin remove szalikdev.plugin-updates
```

## Manual refresh

```
omarchy-shell -q szalikdev.plugin-updates refresh
```
