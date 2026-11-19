#!/usr/bin/env bash
# Create a budget with alerts at 50%, 90% and 100% of BUDGET_AMOUNT.
# Run this before 10_infra.sh. A budget sends alerts; it does not stop spending.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require PROJECT_ID BILLING_ACCOUNT BUDGET_AMOUNT

gcloud billing budgets create \
  --billing-account="$BILLING_ACCOUNT" \
  --display-name="nutrilens-${PROJECT_ID}" \
  --budget-amount="$BUDGET_AMOUNT" \
  --filter-projects="projects/${PROJECT_ID}" \
  --threshold-rule=percent=0.5 \
  --threshold-rule=percent=0.9 \
  --threshold-rule=percent=1.0
