#!/usr/bin/env bash
# Static contract checks for /octo:embrace command.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/../helpers/test-framework.sh"
test_suite "embrace command contract"

COMMAND_FILE="$PROJECT_ROOT/.claude/commands/embrace.md"

test_case "embrace command delegates to the single runner"
content="$(cat "$COMMAND_FILE")"
if [[ "$content" == *'bash scripts/orchestrate.sh embrace'* ]] && \
   [[ "$content" == *'OCTOPUS_DEBATE_GATES='* ]]; then
    test_pass
else
    test_fail "expected command to invoke scripts/orchestrate.sh embrace with debate gate env"
fi

test_case "embrace command does not instruct manual phase execution"
if grep -qE 'scripts/orchestrate\.sh (probe|grasp|tangle|ink)' "$COMMAND_FILE"; then
    test_fail "found direct phase execution instruction in embrace command"
else
    test_pass
fi

test_case "embrace command forbids local implementation fallback"
if grep -qi 'must not execute phases manually' "$COMMAND_FILE" && \
   grep -qi 'Do not continue manually' "$COMMAND_FILE"; then
    test_pass
else
    test_fail "expected explicit prohibition against manual phase or implementation fallback"
fi

test_summary
