# claude-usage-meter

A status line for [Claude Code](https://claude.com/claude-code) that keeps your
session and weekly usage visible at all times, so you do not have to keep
running `/usage`.

![Status line preview](docs/preview.svg)

## What it shows

| Segment | Meaning |
| --- | --- |
| `Sonnet 5.5` | Current model |
| `claude-usage-meter` | Name of the current folder |
| `ctx ███░░░░░ 34%` | How full the context window is |
| `session ██░░░░░░ 24% (2h14m)` | Usage of the 5-hour limit, and time until it resets |
| `week ██████░░ 78% (3d4h)` | Usage of the 7-day limit, and time until it resets |
| `$1.23` | Estimated cost of this session |

Each meter is green below 70%, yellow from 70%, and red from 90%. Anything
Claude Code does not report is simply left out.

## Install

Requires `jq`. The session and weekly meters need a Claude.ai subscription,
and appear after the first response in a session.

    git clone https://github.com/whbrewer/claude-usage-meter
    cd claude-usage-meter
    make install

Restart Claude Code afterwards. `make install` copies the script to
`~/.claude/usage-meter.sh` and sets `statusLine` in `~/.claude/settings.json`
(the previous file is saved as `settings.json.bak`).

Use `CLAUDE_DIR=/path make install` for a non-default config directory.

## Uninstall

    make uninstall

## Test

    make test

Runs the script against sample input and prints the result.
