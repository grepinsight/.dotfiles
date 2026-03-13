SOURCE := $(CURDIR)/.claude/CLAUDE.md
TARGET := $(HOME)/.claude/CLAUDE.md
MERGE_TOOL ?= vimdiff

configure:
	@mkdir -p $(HOME)/.claude
	@if [ -L "$(TARGET)" ] && [ "$$(readlink "$(TARGET)")" = "$(SOURCE)" ]; then \
		echo "$(TARGET) is already linked correctly. Nothing to do."; \
	elif [ ! -e "$(TARGET)" ]; then \
		ln -sf "$(SOURCE)" "$(TARGET)"; \
		echo "Linked $(TARGET) -> $(SOURCE)"; \
	else \
		echo ""; \
		echo "Existing file found at $(TARGET)"; \
		echo ""; \
		diff -u "$(TARGET)" "$(SOURCE)" && { \
			echo "Files are identical. Replacing with symlink."; \
			ln -sf "$(SOURCE)" "$(TARGET)"; \
			echo "Linked $(TARGET) -> $(SOURCE)"; \
			exit 0; \
		}; \
		echo ""; \
		echo "Choose an action:"; \
		echo "  [o] Override - backup existing file, replace with symlink"; \
		echo "  [m] Merge   - open in $(MERGE_TOOL) to reconcile differences"; \
		echo "  [c] Cancel  - do nothing"; \
		echo ""; \
		printf "Choice [o/m/c]: "; \
		read choice; \
		case "$$choice" in \
			o|O) \
				backup="$(TARGET).$$(date +%Y%m%d%H%M%S).bak"; \
				cp "$(TARGET)" "$$backup"; \
				echo "Backed up existing file to $$backup"; \
				rm -f "$(TARGET)"; \
				ln -sf "$(SOURCE)" "$(TARGET)"; \
				echo "Linked $(TARGET) -> $(SOURCE)"; \
				;; \
			m|M) \
				backup="$(TARGET).$$(date +%Y%m%d%H%M%S).bak"; \
				cp "$(TARGET)" "$$backup"; \
				echo "Backed up existing file to $$backup"; \
				echo "Opening $(MERGE_TOOL) — edit the LEFT file (dotfiles source) to keep what you need..."; \
				$(MERGE_TOOL) "$(SOURCE)" "$(TARGET)"; \
				echo ""; \
				printf "Replace existing file with symlink to dotfiles source? [y/n]: "; \
				read confirm; \
				case "$$confirm" in \
					y|Y) \
						rm -f "$(TARGET)"; \
						ln -sf "$(SOURCE)" "$(TARGET)"; \
						echo "Linked $(TARGET) -> $(SOURCE)"; \
						;; \
					*) \
						echo "Symlink not created. Your backup is at $$backup"; \
						;; \
				esac; \
				;; \
			*) \
				echo "Cancelled. No changes made."; \
				;; \
		esac; \
	fi
