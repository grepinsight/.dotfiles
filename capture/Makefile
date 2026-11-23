ENTRY_POINTS := capture captures
BIN := $(CURDIR)/bin

configure:
	@mkdir -p $(HOME)/bin
	@for name in $(ENTRY_POINTS); do \
		source="$(BIN)/$$name"; \
		target="$(HOME)/bin/$$name"; \
		if [ -L "$$target" ] && [ "$$(readlink "$$target")" = "$$source" ]; then \
			echo "$$target is already linked correctly."; \
		elif [ -L "$$target" ]; then \
			ln -sf "$$source" "$$target"; \
			echo "Repointed $$target -> $$source"; \
		elif [ ! -e "$$target" ]; then \
			ln -s "$$source" "$$target"; \
			echo "Linked $$target -> $$source"; \
		else \
			echo "Refusing to replace the real file at $$target."; \
			echo "Move it aside, then re-run: make -C $(CURDIR) configure"; \
			exit 1; \
		fi; \
	done

test:
	@python3 -m unittest discover -s $(CURDIR)/tests

.PHONY: configure test
