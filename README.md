# claude-usage-meter

Shows your Claude Code session (5-hour) and weekly (7-day) usage in the status
line, so you do not need to keep running `/usage`.

    Sonnet 5.5 | session: 24% | week: 41%

## Install

Requires `jq` and a Claude.ai subscription (usage data is only provided for those).

    make install

Restart Claude Code afterwards. Remove with `make uninstall`.
Use `CLAUDE_DIR=/path make install` for a non-default config directory.
