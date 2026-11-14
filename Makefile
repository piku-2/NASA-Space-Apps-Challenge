PYTHON ?= python3

.PHONY: check-text typecheck test check build dev preview

check-text:
	$(PYTHON) scripts/check_text.py

typecheck:
	npm run typecheck

test: check-text
	npm run test

check:
	npm run check

build:
	npm run build

dev:
	npm run dev

preview:
	npm run preview
