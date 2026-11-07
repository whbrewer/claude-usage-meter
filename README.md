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
| `5h ██░░░░░░ 24% (2h14m) 0.6x` | Usage of the 5-hour limit, time until it resets, and burn rate |
| `7d ██████░░ 78% (3d4h) 1.6x` | Usage of the 7-day limit, time until it resets, and burn rate |
| `ease off, week on pace for 156%` | Recommendation (also `room to burn`, `5h cap in 29m`, `on pace`) |
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

## Burn rate

The `x` tag is burn rate: usage % divided by the % of the window already
elapsed. `1.0x` is exactly on pace to hit 100% at reset; green is under, yellow
over, red 1.25x or more. It is hidden for the first 10% of each window, where
the ratio is noise. The recommendation uses the weekly rate (`ease off` at
1.05x or more, `room to burn` under 0.7x) and warns if the current session
will hit its cap within the hour. Set `USAGE_METER_NO_ADVICE=1` to hide it.

## burnplan

`make install` also puts `burnplan` in `~/.local/bin`. The status line logs
each change in session/week usage to `~/.claude/usage-meter/samples.jsonl`,
and `burnplan` turns that log into a timed plan: what to do right now, and a
block-by-block burn schedule for next week. It answers: how much of this week's budget can I
still spend, and when do I need to start burning next week so none is left over?

    burnplan                              # plan from the latest logged usage
    burnplan --active 07:00-22:00 --save  # hours you are around (default 08:00-23:00)
    burnplan --job-rate 25 --save         # session %/h per /deep-research job
    burnplan --week 45 --session 22 --session-reset 59m --week-reset 3.5h --x 12

It measures X (weekly % used by one full 5-hour session) from windows in the
log where session usage rose by 10+ points; until then, pass `--x`. The burn
rate defaults to the fastest sustained burn in the log (or 40 %/h). Set
`USAGE_METER_NO_LOG=1` to turn logging off.
