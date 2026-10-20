CLAUDE_DIR ?= $(HOME)/.claude
SETTINGS   := $(CLAUDE_DIR)/settings.json
SCRIPT     := $(CLAUDE_DIR)/usage-meter.sh

.PHONY: install uninstall test help

help:
	@echo "make install    install the usage meter status line"
	@echo "make uninstall  remove it"
	@echo "make test       run the script against sample input"

install:
	@command -v jq >/dev/null || { echo "jq is required"; exit 1; }
	@mkdir -p $(CLAUDE_DIR)
	@[ -f $(SETTINGS) ] || echo '{}' > $(SETTINGS)
	install -m 755 src/statusline.sh $(SCRIPT)
	@cp $(SETTINGS) $(SETTINGS).bak
	@jq '.statusLine = {type: "command", command: "$(SCRIPT)"}' $(SETTINGS).bak > $(SETTINGS)
	@echo "Installed. Backup of settings at $(SETTINGS).bak. Restart Claude Code."

uninstall:
	@rm -f $(SCRIPT)
	@[ ! -f $(SETTINGS) ] || { cp $(SETTINGS) $(SETTINGS).bak; jq 'del(.statusLine)' $(SETTINGS).bak > $(SETTINGS); }
	@echo "Uninstalled."

test:
	@echo '{"model":{"display_name":"Sonnet 5.5"},"cost":{"total_cost_usd":1.2345},"context_window":{"used_percentage":34},"rate_limits":{"five_hour":{"used_percentage":23.5},"seven_day":{"used_percentage":78.2}}}' | bash src/statusline.sh
