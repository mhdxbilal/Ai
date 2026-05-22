#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/../helpers/test-framework.sh"

test_suite "Council Command"

test_council_command_files_are_registered() {
    test_case "Council command and skill are registered"

    local command_file="$PROJECT_ROOT/.claude/commands/council.md"
    local skill_file="$PROJECT_ROOT/skills/skill-council/SKILL.md"
    local plugin_file="$PROJECT_ROOT/.claude-plugin/plugin.json"

    [[ -f "$command_file" ]] || { test_fail "Missing $command_file"; return 1; }
    [[ -f "$skill_file" ]] || { test_fail "Missing $skill_file"; return 1; }

    if jq -e '.commands[] | select(. == "./.claude/commands/council.md")' "$plugin_file" >/dev/null &&
       jq -e '.skills[] | select(. == "./skills/skill-council")' "$plugin_file" >/dev/null; then
        test_pass
    else
        test_fail "plugin.json missing council command or skill"
        return 1
    fi
}

test_council_orchestrate_route_exists() {
    test_case "orchestrate.sh routes council command"

    if grep -q 'council)' "$PROJECT_ROOT/scripts/orchestrate.sh" &&
       grep -q 'council_run' "$PROJECT_ROOT/scripts/orchestrate.sh"; then
        test_pass
    else
        test_fail "council route missing"
        return 1
    fi
}

load_council_lib() {
    local lib="$PROJECT_ROOT/scripts/lib/council.sh"
    if [[ ! -f "$lib" ]]; then
        test_fail "Missing $lib"
        return 1
    fi
    # shellcheck disable=SC1090
    source "$lib"
}

test_council_defaults_are_depth_aware() {
    test_case "Council defaults are depth aware"
    load_council_lib || return 1

    council_parse_args --depth standard --dry-run "Review auth"

    [[ "$COUNCIL_DEPTH" == "standard" ]] || { test_fail "depth not parsed"; return 1; }
    [[ "$COUNCIL_MEMBERS" == "auto" ]] || { test_fail "members default not auto"; return 1; }
    [[ "$COUNCIL_RESOLVED_MEMBERS" == "5" ]] || { test_fail "standard should resolve to 5 members"; return 1; }
    [[ "$COUNCIL_MAX_COST" == "2.00" ]] || { test_fail "standard default budget should be 2.00"; return 1; }
    test_pass
}

test_council_rejects_non_usd_budget() {
    test_case "Council rejects non-USD budget values"
    load_council_lib || return 1

    local out_file="$TEST_TMP_DIR/council-budget.out"
    set +e
    council_parse_args --max-cost '$2.00' "Review auth" >"$out_file" 2>&1
    local status=$?
    set -e

    [[ $status -eq 2 ]] || { test_fail "expected exit code 2, got $status"; return 1; }
    grep -q "USD decimal" "$out_file" || { test_fail "missing usage hint"; return 1; }
    test_pass
}

test_council_dry_run_writes_summary_json() {
    test_case "Council dry-run writes summary JSON"
    load_council_lib || return 1

    local tmp_dir
    tmp_dir="$(mktemp -d "$TEST_TMP_DIR/council.XXXXXX")"

    council_run --dry-run --goal advice --depth quick --output-dir "$tmp_dir" "Should we use Redis?"

    local summary
    summary="$(find "$tmp_dir" -name summary.json -type f | head -1)"
    [[ -n "$summary" ]] || { test_fail "summary.json not written"; return 1; }

    if jq -e '.command == "council" and .status == "dry-run" and .implementation.worktree == "auto"' "$summary" >/dev/null; then
        test_pass
    else
        test_fail "summary JSON contract mismatch"
        return 1
    fi
}

test_council_explicit_members_override_depth() {
    test_case "Explicit members override depth member preset"
    load_council_lib || return 1

    council_parse_args --depth quick --members 7 --dry-run "Review auth"

    [[ "$COUNCIL_RESOLVED_MEMBERS" == "7" ]] || { test_fail "explicit members should win"; return 1; }
    [[ "$COUNCIL_MEMBER_OVERRIDE_WARNING" == "true" ]] || { test_fail "missing member override warning"; return 1; }
    test_pass
}

test_council_dry_run_maps_implementation_and_worktree() {
    test_case "Council dry-run maps implementation and worktree flags"
    load_council_lib || return 1

    local tmp_dir
    tmp_dir="$(mktemp -d "$TEST_TMP_DIR/council-impl.XXXXXX")"

    council_run --dry-run --goal implement --implement after-approval --worktree on --output-dir "$tmp_dir" "Refactor auth flow"

    local summary
    summary="$(find "$tmp_dir" -name summary.json -type f | head -1)"
    [[ -n "$summary" ]] || { test_fail "summary.json not written"; return 1; }

    if jq -e '.implementation.permission == "after-approval" and .implementation.worktree == "on"' "$summary" >/dev/null; then
        test_pass
    else
        test_fail "implementation/worktree mapping mismatch"
        return 1
    fi
}

test_council_dry_run_has_multi_seat_recommendation_and_cost() {
    test_case "Council dry-run has multiple seats and positive cost estimate"
    load_council_lib || return 1

    local tmp_dir
    tmp_dir="$(mktemp -d "$TEST_TMP_DIR/council-cost.XXXXXX")"

    council_run --dry-run --depth quick --output-dir "$tmp_dir" "Should we use Redis?"

    local summary
    summary="$(find "$tmp_dir" -name summary.json -type f | head -1)"
    [[ -n "$summary" ]] || { test_fail "summary.json not written"; return 1; }

    if jq -e '(.council | length) >= 2 and .budget.estimated_cost_usd > 0' "$summary" >/dev/null; then
        test_pass
    else
        test_fail "missing multi-seat recommendation or positive cost"
        return 1
    fi
}

test_council_critical_veto_fixture_marks_veto() {
    test_case "Critical veto fixture marks veto path"
    load_council_lib || return 1

    local tmp_dir
    tmp_dir="$(mktemp -d "$TEST_TMP_DIR/council-veto.XXXXXX")"

    OCTOPUS_COUNCIL_FIXTURE=critical-veto \
        council_run --dry-run --goal implement --output-dir "$tmp_dir" "Ship this without tests"

    local summary
    summary="$(find "$tmp_dir" -name summary.json -type f | head -1)"
    [[ -n "$summary" ]] || { test_fail "summary.json not written"; return 1; }

    if jq -e '.veto.triggered == true and .veto.severity == "critical"' "$summary" >/dev/null; then
        test_pass
    else
        test_fail "critical veto fixture did not trigger veto"
        return 1
    fi
}

test_council_command_files_are_registered
test_council_orchestrate_route_exists
test_council_defaults_are_depth_aware
test_council_rejects_non_usd_budget
test_council_dry_run_writes_summary_json
test_council_explicit_members_override_depth
test_council_dry_run_maps_implementation_and_worktree
test_council_dry_run_has_multi_seat_recommendation_and_cost
test_council_critical_veto_fixture_marks_veto
test_summary
