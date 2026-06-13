# PlasmaSafe

PlasmaSafe is a command-line backup, restore, diff, verify, export, and import tool for KDE Plasma configuration.

It is designed for Arch Linux KDE Plasma users who customize their desktop and want a safe way to snapshot Plasma/KWin settings before changing themes, panels, widgets, shortcuts, effects, or desktop configuration.

## Features

- Save KDE Plasma configuration snapshots
- List snapshots
- Show snapshot details
- Output snapshot details as JSON
- Compare two snapshots
- Restore snapshots with dry-run support
- Automatically create a safety snapshot before real restore
- Verify snapshot integrity
- Export snapshots to `.tar.gz`
- Import snapshots from `.tar.gz`
- Delete snapshots safely
- Show available backup profiles
- Run an environment doctor
- Supports fake home testing through `PLASMASAFE_HOME`

## Commands

    plasmasafe save NAME
    plasmasafe save NAME --profile minimal
    plasmasafe save NAME --profile desktop
    plasmasafe save NAME --profile full

    plasmasafe list
    plasmasafe list --json

    plasmasafe show SNAPSHOT
    plasmasafe show SNAPSHOT --json

    plasmasafe diff OLD NEW

    plasmasafe restore SNAPSHOT --dry-run
    plasmasafe restore SNAPSHOT --force

    plasmasafe verify SNAPSHOT
    plasmasafe verify SNAPSHOT --json

    plasmasafe delete SNAPSHOT
    plasmasafe delete SNAPSHOT --force

    plasmasafe export SNAPSHOT output.tar.gz
    plasmasafe import archive.tar.gz

    plasmasafe profiles
    plasmasafe doctor

## Profiles

PlasmaSafe currently has three profiles.

### minimal

Backs up the most important Plasma/KWin configuration files:

- Plasma desktop, panel, and widget layout
- Plasma shell config
- KWin config
- Global shortcuts
- KDE global settings

### desktop

Includes `minimal`, plus extra desktop application and session configuration:

- lock screen config
- Dolphin config
- Konsole config
- KRunner config
- session config
- mouse/input config
- accessibility config
- Breeze config
- selected local Plasma/Konsole directories

### full

Includes `desktop`, plus more KDE appearance and customization paths:

- KWin rules
- splash screen config
- MIME app associations
- color schemes
- icon themes
- wallpapers
- KWin local data
- Plasma System Monitor data
- user application launchers

`full` is still conservative. It does not blindly copy all of `~/.config`.

## Snapshot location

Snapshots are stored under:

    ~/.local/state/plasmasafe/snapshots/

If `XDG_STATE_HOME` is set, PlasmaSafe uses:

    $XDG_STATE_HOME/plasmasafe/snapshots/

For testing, you can override the home directory:

    PLASMASAFE_HOME=/tmp/fakehome cabal run plasmasafe -- save test

## Safety model

PlasmaSafe is intentionally conservative.

Non-destructive commands:

- save
- list
- show
- diff
- verify
- doctor
- profiles
- export

Restore requires an explicit flag:

    plasmasafe restore SNAPSHOT --dry-run
    plasmasafe restore SNAPSHOT --force

Before `--force` restore, PlasmaSafe automatically creates a safety snapshot:

    auto-before-restore-SNAPSHOT

Delete also requires an explicit force flag:

    plasmasafe delete SNAPSHOT --force

Without `--force`, delete only shows a preview.

## Development

Build:

    cabal build

Run:

    cabal run plasmasafe -- --help

Run tests:

    ./test-plasmasafe.sh

## Fake home testing

Create a fake Plasma home:

    ./make-fake-home.sh

Then test safely:

    PLASMASAFE_HOME=/tmp/fakehome cabal run plasmasafe -- save fake-test
    PLASMASAFE_HOME=/tmp/fakehome cabal run plasmasafe -- list
    PLASMASAFE_HOME=/tmp/fakehome cabal run plasmasafe -- show fake-test

## Install locally

    cabal install exe:plasmasafe --installdir="$HOME/.local/bin" --overwrite-policy=always

Make sure `~/.local/bin` is in your `PATH`.

For zsh:

    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
    source ~/.zshrc

Then:

    plasmasafe --help

