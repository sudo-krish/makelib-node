# ==============================================================================
# .makelib/colors.mk — Terminal Colors & Output Helpers
# ==============================================================================

COLOR_RESET   := \033[0m
COLOR_BOLD    := \033[1m
COLOR_DIM     := \033[2m
COLOR_RED     := \033[31m
COLOR_GREEN   := \033[32m
COLOR_YELLOW  := \033[33m
COLOR_BLUE    := \033[34m
COLOR_MAGENTA := \033[35m
COLOR_CYAN    := \033[36m
COLOR_WHITE   := \033[37m

# Formatted log prefixes
INFO_PREFIX    := $(COLOR_CYAN)[INFO]$(COLOR_RESET)
SUCCESS_PREFIX := $(COLOR_GREEN)[SUCCESS]$(COLOR_RESET)
WARN_PREFIX    := $(COLOR_YELLOW)[WARN]$(COLOR_RESET)
ERROR_PREFIX   := $(COLOR_RED)[ERROR]$(COLOR_RESET)
GATE_PREFIX    := $(COLOR_MAGENTA)[GATE]$(COLOR_RESET)
