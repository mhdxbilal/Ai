#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/../helpers/test-framework.sh"

log() { :; }
source "$PROJECT_ROOT/scripts/lib/utils.sh"

test_suite "Agent Command Validation"

test_case "validate_agent_command allows vibe-exec shim path"
if validate_agent_command "$PROJECT_ROOT/scripts/helpers/vibe-exec.sh --output text"; then
    test_pass
else
    test_fail "expected vibe-exec shim path to be accepted"
fi

test_case "validate_agent_command allows vibe-exec shim path without args"
if validate_agent_command "$PROJECT_ROOT/scripts/helpers/vibe-exec.sh"; then
    test_pass
else
    test_fail "expected bare vibe-exec shim path to be accepted"
fi

test_case "validate_agent_command rejects embedded vibe-exec shim path"
if validate_agent_command "echo $PROJECT_ROOT/scripts/helpers/vibe-exec.sh --output text" >/dev/null 2>&1; then
    test_fail "expected embedded vibe-exec shim path to be rejected"
else
    test_pass
fi

test_case "validate_agent_command rejects unsafe command"
if validate_agent_command "rm -rf /" >/dev/null 2>&1; then
    test_fail "expected unsafe command to be rejected"
else
    test_pass
fi

test_summary
