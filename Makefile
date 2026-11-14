GODOT ?= godot
PYTHON ?= python3
TEST_DATA := $(CURDIR)/.godot/test-user-data

.PHONY: check-text import test run export-web serve

check-text:
	$(PYTHON) scripts/check_text.py

import:
	GODOT_MCP_RUNTIME=0 $(GODOT) --headless --path . --editor --import

test: check-text import
	mkdir -p "$(TEST_DATA)"
	XDG_DATA_HOME="$(TEST_DATA)" GODOT_MCP_RUNTIME=0 $(GODOT) --headless --path . --script test/run_tests.gd
	XDG_DATA_HOME="$(TEST_DATA)" GODOT_MCP_RUNTIME=0 $(GODOT) --headless --path . --script test/ui_checks.gd

run:
	GODOT_MCP_RUNTIME=0 $(GODOT) --path .

export-web: import
	mkdir -p dist
	GODOT_MCP_RUNTIME=0 $(GODOT) --headless --path . --export-release "Web" dist/index.html

serve:
	$(PYTHON) -m http.server 8000 --bind 127.0.0.1 --directory dist
