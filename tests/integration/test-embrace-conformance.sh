#!/usr/bin/env bash
# Tokenless Embrace conformance tests. Providers are mocked through PATH.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/../helpers/test-framework.sh"
test_suite "embrace conformance"

BASE_TMP="${TEST_TMP_DIR}/embrace-conformance"
FAKE_BIN="${BASE_TMP}/bin"
ORIGINAL_PATH="$PATH"

write_fake_providers() {
    mkdir -p "$FAKE_BIN"

    cat > "$FAKE_BIN/codex" <<'SH'
#!/usr/bin/env bash
input="$(cat)"
[[ -f "$HOME/.octo-fake-mode" ]] && source "$HOME/.octo-fake-mode"
printf 'codex %s\n' "$*" >> "$HOME/providers.log"

emit_long() {
    local title="$1"
    echo "$title"
    for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
        echo "codex detail ${i}: deterministic conformance evidence for Embrace orchestration contracts and artifact checks."
    done
}

if [[ "${OCTO_FAKE_CODEX_STDERR_ONLY:-false}" == "true" ]]; then
    emit_long "codex usable stderr-only response" >&2
    exit 0
fi

if [[ "$input" == *"Decompose this task into subtasks"* ]]; then
    if [[ "${OCTO_FAKE_TANGLE_FAIL:-false}" == "true" ]]; then
        echo "1. [CODING] TANGLE_SUBTASK_FAIL"
    else
        echo "1. [CODING] Implement deterministic conformance marker"
    fi
    exit 0
fi

if [[ "${OCTO_FAKE_TANGLE_FAIL:-false}" == "true" && "$input" == *"TANGLE_SUBTASK_FAIL"* ]]; then
    echo "codex simulated tangle failure" >&2
    exit 1
fi

emit_long "codex deterministic response"
SH

    cat > "$FAKE_BIN/gemini" <<'SH'
#!/usr/bin/env bash
input="$(cat)"
[[ -f "$HOME/.octo-fake-mode" ]] && source "$HOME/.octo-fake-mode"
printf 'gemini %s\n' "$*" >> "$HOME/providers.log"

emit_long() {
    local title="$1"
    echo "$title"
    for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
        echo "gemini detail ${i}: deterministic conformance evidence for Embrace orchestration contracts and artifact checks."
    done
}

if [[ "${OCTO_FAKE_GEMINI_QUOTA:-false}" == "true" ]]; then
    echo "QUOTA_EXHAUSTED: fake Gemini quota exhausted" >&2
    exit 1
fi

if [[ "$input" == *"Decompose this task into subtasks"* ]]; then
    if [[ "${OCTO_FAKE_TANGLE_FAIL:-false}" == "true" ]]; then
        echo "1. [CODING] TANGLE_SUBTASK_FAIL"
    else
        echo "1. [CODING] Implement deterministic conformance marker"
    fi
    exit 0
fi

if [[ "$input" == *"Rate each dimension explicitly"* ]]; then
    echo "Security: 10/10"
    echo "Reliability: 10/10"
    echo "Performance: 10/10"
    echo "Accessibility: 10/10"
    exit 0
fi

emit_long "gemini deterministic response"
SH

    cat > "$FAKE_BIN/claude" <<'SH'
#!/usr/bin/env bash
input="$(cat)"
[[ -f "$HOME/.octo-fake-mode" ]] && source "$HOME/.octo-fake-mode"
printf 'claude %s\n' "$*" >> "$HOME/providers.log"

if [[ "$input" == *"Rate each dimension explicitly"* ]]; then
    echo "Security: 10/10"
    echo "Reliability: 10/10"
    echo "Performance: 10/10"
    echo "Accessibility: 10/10"
    exit 0
fi

echo "claude deterministic response"
for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
    echo "claude detail ${i}: deterministic conformance evidence for Embrace orchestration contracts and artifact checks."
done
SH

    chmod +x "$FAKE_BIN/codex" "$FAKE_BIN/gemini" "$FAKE_BIN/claude"
}

run_embrace_case() {
    local name="$1"
    shift
    local run_dir="${BASE_TMP}/${name}"
    local workspace="${run_dir}/workspace"
    local home="${run_dir}/home"
    local out="${run_dir}/out.txt"
    local rc_file="${run_dir}/rc.txt"

    rm -rf "$run_dir"
    mkdir -p "$workspace" "$home"
    cat > "$home/.octo-fake-mode" <<EOF
OCTO_FAKE_TANGLE_FAIL="${OCTO_FAKE_TANGLE_FAIL:-false}"
OCTO_FAKE_GEMINI_QUOTA="${OCTO_FAKE_GEMINI_QUOTA:-false}"
OCTO_FAKE_CODEX_STDERR_ONLY="${OCTO_FAKE_CODEX_STDERR_ONLY:-false}"
EOF

    set +e
    env \
        HOME="$home" \
        PATH="$FAKE_BIN:$ORIGINAL_PATH" \
        OPENAI_API_KEY="fake-openai-key" \
        GEMINI_API_KEY="fake-gemini-key" \
        CLAUDE_OCTOPUS_WORKSPACE="$workspace" \
        OCTOPUS_CONFORMANCE_MODE=true \
        OCTOPUS_SKIP_COST_PROMPT=true \
        OCTOPUS_SKIP_PROVIDER_PROBES=true \
        SKIP_SMOKE_TEST=true \
        OCTOPUS_DEBATE_GATES="${OCTOPUS_DEBATE_GATES:-both}" \
        OCTOPUS_DISPATCH_STRATEGY=full \
        OCTOPUS_TANGLE_DEADLINE=30 \
        OCTOPUS_AGENT_MAX_OUTPUT_BYTES=65536 \
        OCTO_FAKE_TANGLE_FAIL="${OCTO_FAKE_TANGLE_FAIL:-false}" \
        OCTO_FAKE_GEMINI_QUOTA="${OCTO_FAKE_GEMINI_QUOTA:-false}" \
        OCTO_FAKE_CODEX_STDERR_ONLY="${OCTO_FAKE_CODEX_STDERR_ONLY:-false}" \
        OCTOPUS_CONFORMANCE_SKIP_GATE_ARTIFACT="${OCTOPUS_CONFORMANCE_SKIP_GATE_ARTIFACT:-}" \
        "$@" \
        bash "$PROJECT_ROOT/scripts/orchestrate.sh" --timeout 30 embrace "conformance ${name}" \
        >"$out" 2>&1
    local rc=$?
    set -e

    echo "$rc" > "$rc_file"
    echo "$run_dir"
}

assert_file_glob() {
    local pattern="$1"
    compgen -G "$pattern" >/dev/null
}

write_fake_providers

test_case "successful run writes all phase and gate artifacts without live providers"
run_dir="$(OCTOPUS_DEBATE_GATES=both run_embrace_case success)"
rc="$(cat "$run_dir/rc.txt")"
results="$run_dir/workspace/results"
if [[ "$rc" == "0" ]] && \
   assert_file_glob "$results/probe-synthesis-*.md" && \
   assert_file_glob "$results/grasp-consensus-*.md" && \
   assert_file_glob "$results/tangle-validation-*.md" && \
   assert_file_glob "$results/delivery-*.md" && \
   assert_file_glob "$results/embrace-gate-define-develop-*.md" && \
   assert_file_glob "$results/embrace-gate-deliver-*.md" && \
   grep -q '^codex ' "$run_dir/home/providers.log" && \
   grep -q '^gemini ' "$run_dir/home/providers.log" && \
   grep -q '^claude ' "$run_dir/home/providers.log"; then
    test_pass
else
    test_fail "expected successful conformance run with all artifacts; rc=${rc}; output=$(tail -40 "$run_dir/out.txt")"
fi

test_case "failed tangle stops before delivery but preserves validation artifact"
run_dir="$(OCTOPUS_DEBATE_GATES=none OCTO_FAKE_TANGLE_FAIL=true run_embrace_case tangle-failed)"
rc="$(cat "$run_dir/rc.txt")"
results="$run_dir/workspace/results"
if [[ "$rc" != "0" ]] && \
   assert_file_glob "$results/tangle-validation-*.md" && \
   ! assert_file_glob "$results/delivery-*.md" && \
   grep -q "Quality Gate: FAILED" "$results"/tangle-validation-*.md; then
    test_pass
else
    test_fail "expected tangle failure to block delivery; rc=${rc}; output=$(tail -40 "$run_dir/out.txt")"
fi

test_case "requested missing debate gate artifact fails the workflow"
run_dir="$(OCTOPUS_DEBATE_GATES=both OCTOPUS_CONFORMANCE_SKIP_GATE_ARTIFACT=define-develop run_embrace_case missing-gate)"
rc="$(cat "$run_dir/rc.txt")"
results="$run_dir/workspace/results"
if [[ "$rc" != "0" ]] && \
   assert_file_glob "$results/grasp-consensus-*.md" && \
   ! assert_file_glob "$results/embrace-gate-define-develop-*.md" && \
   ! assert_file_glob "$results/tangle-validation-*.md"; then
    test_pass
else
    test_fail "expected missing requested gate artifact to stop workflow; rc=${rc}; output=$(tail -40 "$run_dir/out.txt")"
fi

test_case "Gemini quota exhaustion degrades through fallback artifacts"
run_dir="$(OCTOPUS_DEBATE_GATES=none OCTO_FAKE_GEMINI_QUOTA=true run_embrace_case gemini-quota)"
rc="$(cat "$run_dir/rc.txt")"
results="$run_dir/workspace/results"
if [[ "$rc" == "0" ]] && \
   assert_file_glob "$results/probe-synthesis-*.md" && \
   assert_file_glob "$results/grasp-consensus-*.md" && \
   assert_file_glob "$results/delivery-*.md" && \
   grep -q "Auto-synthesis failed\\|Auto-consensus failed\\|raw findings" "$results"/probe-synthesis-*.md "$results"/grasp-consensus-*.md "$results"/delivery-*.md; then
    test_pass
else
    test_fail "expected Gemini quota fallback artifacts; rc=${rc}; output=$(tail -40 "$run_dir/out.txt")"
fi

test_case "Codex stderr-only output is degraded usable output"
run_dir="$(OCTOPUS_DEBATE_GATES=none OCTO_FAKE_CODEX_STDERR_ONLY=true run_embrace_case codex-stderr)"
rc="$(cat "$run_dir/rc.txt")"
results="$run_dir/workspace/results"
if [[ "$rc" == "0" ]] && \
   assert_file_glob "$results/tangle-validation-*.md" && \
   grep -q "Status: SUCCESS (DEGRADED: Output captured on stderr)" "$results"/*codex*tangle-*.md; then
    test_pass
else
    test_fail "expected Codex stderr-only output to count as degraded success; rc=${rc}; output=$(tail -40 "$run_dir/out.txt")"
fi

test_summary
