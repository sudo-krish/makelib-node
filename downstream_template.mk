# ==============================================================================
# Downstream Makefile for makelib-node
# ==============================================================================
# Add makelib-node as a Git submodule into .makelib (recommended) or makelib:
#   git submodule add https://github.com/sudo-krish/makelib-node.git .makelib
#
# Then run:
#   make init        # Installs isolated makelib toolchain & Git hooks
#   make check-all   # Runs full 8-stage quality gate pipeline
#   make help        # Displays self-documenting help menu
# ==============================================================================

# Submodule directory (.makelib by default, or makelib)
MAKELIB_DIR ?= $(firstword $(wildcard .makelib makelib))

# Downstream Overrides (uncomment and customize as needed)
# SRC_DIR      ?= src
# TEST_DIR     ?= test
# MIN_COVERAGE ?= 80
# NO_DEFAULT_BUILD := 1   # Uncomment if downstream defines its own custom build target

-include $(MAKELIB_DIR)/core.mk
