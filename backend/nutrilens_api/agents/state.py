"""Names of the values the agents share through session state."""

APP_NAME = "nutrilens_label_review"

# Inputs written before the run.
LABEL_KEY = "label_text"
FLAGS_KEY = "profile_flags"

# Set by the tools.
SOURCES_KEY = "sources"
SEARCH_COUNT_KEY = "search_calls"

# Set by the agents, each from its final answer.
INGREDIENTS_KEY = "ingredients_found"
FINDINGS_KEY = "research_findings"
REVIEW_KEY = "profile_review"
VERIFICATION_KEY = "verification"
