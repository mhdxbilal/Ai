#!/usr/bin/env bash
# Claude Octopus Council command helpers.
# Source-safe: defines functions only.

COUNCIL_GOAL=""
COUNCIL_DOMAIN=""
COUNCIL_STYLE=""
COUNCIL_DEPTH=""
COUNCIL_MEMBERS=""
COUNCIL_RESOLVED_MEMBERS=""
COUNCIL_PERSONAS=""
COUNCIL_IMPLEMENT=""
COUNCIL_WORKTREE=""
COUNCIL_BENCHMARK=""
COUNCIL_PROVIDERS=""
COUNCIL_MAX_COST=""
COUNCIL_DRY_RUN=""
COUNCIL_JSON=""
COUNCIL_OUTPUT_DIR=""
COUNCIL_TASK=""
COUNCIL_RUN_DIR=""
COUNCIL_RUN_ID=""
COUNCIL_FIXTURE=""
COUNCIL_MEMBER_OVERRIDE_WARNING=""
COUNCIL_ESTIMATED_COST=""

council_usage() {
    cat << EOF
Usage: $(basename "${0:-orchestrate.sh}") council [OPTIONS] <task>

Options:
  --goal advice|decision|plan|implement|review
  --domain auto|architecture|product|security|business|research|docs
  --style balanced|adversarial|implementation|executive|red-team
  --depth quick|standard|deep
  --members auto|3|5|7
  --persona <name>[,<name>]
  --implement never|after-approval|plan-only
  --worktree auto|on|off
  --benchmark auto|on|off
  --providers auto|claude,codex,gemini,opencode,openrouter
  --max-cost <usd>
  --dry-run
  --json
  --output-dir <path>

Budget values are USD decimal numbers only, for example: 2, 2.00, 0.50.
EOF
}

council_reset_defaults() {
    COUNCIL_GOAL="advice"
    COUNCIL_DOMAIN="auto"
    COUNCIL_STYLE="balanced"
    COUNCIL_DEPTH="standard"
    COUNCIL_MEMBERS="auto"
    COUNCIL_RESOLVED_MEMBERS=""
    COUNCIL_PERSONAS=""
    COUNCIL_IMPLEMENT="never"
    COUNCIL_WORKTREE="auto"
    COUNCIL_BENCHMARK="auto"
    COUNCIL_PROVIDERS="auto"
    COUNCIL_MAX_COST=""
    COUNCIL_DRY_RUN="false"
    COUNCIL_JSON="false"
    COUNCIL_OUTPUT_DIR=""
    COUNCIL_TASK=""
    COUNCIL_RUN_DIR=""
    COUNCIL_RUN_ID=""
    COUNCIL_FIXTURE="${OCTOPUS_COUNCIL_FIXTURE:-}"
    COUNCIL_MEMBER_OVERRIDE_WARNING="false"
    COUNCIL_ESTIMATED_COST="0.00"
}

council_error_usage() {
    local message="$1"
    echo "council: $message" >&2
    echo "Run with --help for usage." >&2
}

council_validate_choice() {
    local flag="$1"
    local value="$2"
    local allowed="$3"

    case ",$allowed," in
        *,"$value",*) return 0 ;;
    esac

    council_error_usage "$flag must be one of: ${allowed//,/|}"
    return 2
}

council_validate_budget() {
    local value="$1"

    if [[ ! "$value" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        echo "council: --max-cost must be a USD decimal value such as 2, 2.00, or 0.50." >&2
        return 2
    fi

    awk -v value="$value" 'BEGIN { printf "%.2f", value + 0 }'
}

council_resolve_defaults() {
    local depth_default_members=""
    local depth_default_cost=""
    case "$COUNCIL_DEPTH" in
        quick)
            depth_default_members="3"
            depth_default_cost="0.50"
            ;;
        standard)
            depth_default_members="5"
            depth_default_cost="2.00"
            ;;
        deep)
            depth_default_members="7"
            depth_default_cost="5.00"
            ;;
    esac

    if [[ "$COUNCIL_MEMBERS" == "auto" ]]; then
        COUNCIL_RESOLVED_MEMBERS="$depth_default_members"
    else
        COUNCIL_RESOLVED_MEMBERS="$COUNCIL_MEMBERS"
        if [[ "$COUNCIL_MEMBERS" != "$depth_default_members" ]]; then
            COUNCIL_MEMBER_OVERRIDE_WARNING="true"
        fi
    fi

    if [[ -z "$COUNCIL_MAX_COST" ]]; then
        COUNCIL_MAX_COST="$depth_default_cost"
    fi
}

council_estimate_cost() {
    local prompt_chars=${#COUNCIL_TASK}
    local input_tokens=$(( (prompt_chars + 3) / 4 ))
    input_tokens=$(( (input_tokens * 125 + 99) / 100 ))

    local multiplier="1.0"
    case "$COUNCIL_DEPTH" in
        quick) multiplier="0.75" ;;
        standard) multiplier="1.0" ;;
        deep) multiplier="1.5" ;;
    esac

    # Conservative mixed-provider default: $3/MTok input, $15/MTok output.
    local estimate
    estimate=$(awk \
        -v input="$input_tokens" \
        -v multiplier="$multiplier" \
        -v members="$COUNCIL_RESOLVED_MEMBERS" \
        'BEGIN {
            output = input * multiplier
            cost = members * (((input / 1000000.0) * 3.0) + ((output / 1000000.0) * 15.0))
            if (cost > 0 && cost < 0.01) {
                cost = 0.01
            }
            printf "%.4f", cost
        }')
    COUNCIL_ESTIMATED_COST="$estimate"
}

council_parse_args() {
    council_reset_defaults

    local positional=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                council_usage
                return 0
                ;;
            --goal)
                [[ $# -ge 2 ]] || { council_error_usage "--goal requires a value"; return 2; }
                COUNCIL_GOAL="$2"
                council_validate_choice "--goal" "$COUNCIL_GOAL" "advice,decision,plan,implement,review" || return 2
                shift 2
                ;;
            --domain)
                [[ $# -ge 2 ]] || { council_error_usage "--domain requires a value"; return 2; }
                COUNCIL_DOMAIN="$2"
                council_validate_choice "--domain" "$COUNCIL_DOMAIN" "auto,architecture,product,security,business,research,docs" || return 2
                shift 2
                ;;
            --style)
                [[ $# -ge 2 ]] || { council_error_usage "--style requires a value"; return 2; }
                COUNCIL_STYLE="$2"
                council_validate_choice "--style" "$COUNCIL_STYLE" "balanced,adversarial,implementation,executive,red-team" || return 2
                shift 2
                ;;
            --depth)
                [[ $# -ge 2 ]] || { council_error_usage "--depth requires a value"; return 2; }
                COUNCIL_DEPTH="$2"
                council_validate_choice "--depth" "$COUNCIL_DEPTH" "quick,standard,deep" || return 2
                shift 2
                ;;
            --members)
                [[ $# -ge 2 ]] || { council_error_usage "--members requires a value"; return 2; }
                COUNCIL_MEMBERS="$2"
                council_validate_choice "--members" "$COUNCIL_MEMBERS" "auto,3,5,7" || return 2
                shift 2
                ;;
            --persona)
                [[ $# -ge 2 ]] || { council_error_usage "--persona requires a value"; return 2; }
                COUNCIL_PERSONAS="$2"
                shift 2
                ;;
            --implement)
                [[ $# -ge 2 ]] || { council_error_usage "--implement requires a value"; return 2; }
                COUNCIL_IMPLEMENT="$2"
                council_validate_choice "--implement" "$COUNCIL_IMPLEMENT" "never,after-approval,plan-only" || return 2
                shift 2
                ;;
            --worktree)
                [[ $# -ge 2 ]] || { council_error_usage "--worktree requires a value"; return 2; }
                COUNCIL_WORKTREE="$2"
                council_validate_choice "--worktree" "$COUNCIL_WORKTREE" "auto,on,off" || return 2
                shift 2
                ;;
            --benchmark)
                [[ $# -ge 2 ]] || { council_error_usage "--benchmark requires a value"; return 2; }
                COUNCIL_BENCHMARK="$2"
                council_validate_choice "--benchmark" "$COUNCIL_BENCHMARK" "auto,on,off" || return 2
                shift 2
                ;;
            --providers)
                [[ $# -ge 2 ]] || { council_error_usage "--providers requires a value"; return 2; }
                COUNCIL_PROVIDERS="$2"
                shift 2
                ;;
            --max-cost)
                [[ $# -ge 2 ]] || { council_error_usage "--max-cost requires a value"; return 2; }
                COUNCIL_MAX_COST="$(council_validate_budget "$2")" || return 2
                shift 2
                ;;
            --dry-run)
                COUNCIL_DRY_RUN="true"
                shift
                ;;
            --json)
                COUNCIL_JSON="true"
                shift
                ;;
            --output-dir)
                [[ $# -ge 2 ]] || { council_error_usage "--output-dir requires a value"; return 2; }
                COUNCIL_OUTPUT_DIR="$2"
                shift 2
                ;;
            --*)
                council_error_usage "unknown option: $1"
                return 2
                ;;
            *)
                positional+=("$1")
                shift
                ;;
        esac
    done

    COUNCIL_TASK="${positional[*]}"
    council_resolve_defaults
}

council_create_run_dir() {
    local parent="$COUNCIL_OUTPUT_DIR"
    if [[ -z "$parent" ]]; then
        parent="${WORKSPACE_DIR:-${HOME}/.claude-octopus}/councils"
    fi

    mkdir -p "$parent" || return 1

    local timestamp
    timestamp="$(date -u +%Y%m%d-%H%M%S)"
    local suffix
    suffix="$(printf '%06x' "$$")"
    COUNCIL_RUN_ID="${timestamp}-${suffix}"
    COUNCIL_RUN_DIR="${parent}/${COUNCIL_RUN_ID}"

    local attempts=0
    while [[ -e "$COUNCIL_RUN_DIR" ]]; do
        attempts=$((attempts + 1))
        COUNCIL_RUN_ID="${timestamp}-${suffix}-${attempts}"
        COUNCIL_RUN_DIR="${parent}/${COUNCIL_RUN_ID}"
    done

    mkdir -p "$COUNCIL_RUN_DIR/responses" "$COUNCIL_RUN_DIR/critiques" || return 1
}

council_write_summary_json() {
    local status="$1"
    local summary_path="${COUNCIL_RUN_DIR}/summary.json"

    council_estimate_cost

    jq -n \
        --arg run_id "$COUNCIL_RUN_ID" \
        --arg status "$status" \
        --arg goal "$COUNCIL_GOAL" \
        --arg domain "$COUNCIL_DOMAIN" \
        --arg style "$COUNCIL_STYLE" \
        --arg depth "$COUNCIL_DEPTH" \
        --arg members "$COUNCIL_RESOLVED_MEMBERS" \
        --arg benchmark "$COUNCIL_BENCHMARK" \
        --arg max_cost "$COUNCIL_MAX_COST" \
        --arg estimated_cost "$COUNCIL_ESTIMATED_COST" \
        --arg providers "$COUNCIL_PROVIDERS" \
        --arg implement "$COUNCIL_IMPLEMENT" \
        --arg worktree "$COUNCIL_WORKTREE" \
        --arg fixture "$COUNCIL_FIXTURE" \
        --arg member_override_warning "$COUNCIL_MEMBER_OVERRIDE_WARNING" \
        --arg task "$COUNCIL_TASK" \
        '{
          run_id: $run_id,
          command: "council",
          status: $status,
          task: $task,
          goal: $goal,
          domain: $domain,
          style: $style,
          depth: $depth,
          members: ($members | tonumber),
          benchmark: {
            mode: $benchmark,
            snapshot_generated_at: null,
            freshness_days: null,
            used: false
          },
          budget: {
            max_cost_usd: ($max_cost | tonumber),
            estimated_cost_usd: ($estimated_cost | tonumber),
            aborted_for_cost: false
          },
          quorum: {
            required_non_chair: (if $depth == "quick" then 1 else 2 end),
            received_non_chair: 0,
            met: false
          },
          providers: $providers,
          warnings: {
            member_override: ($member_override_warning == "true")
          },
          council: [
            {
              seat: "chair",
              persona: "strategy-analyst",
              provider: "claude",
              model: null,
              provider_org: "anthropic",
              score: null,
              benchmark_signal: null
            },
            {
              seat: "advisor",
              persona: "backend-architect",
              provider: "codex",
              model: "gpt-5.3-codex",
              provider_org: "openai",
              score: null,
              benchmark_signal: null
            },
            {
              seat: "skeptic",
              persona: "security-auditor",
              provider: "claude",
              model: null,
              provider_org: "anthropic",
              score: null,
              benchmark_signal: null
            }
          ],
          veto: {
            triggered: ($fixture == "critical-veto"),
            severity: (if $fixture == "critical-veto" then "critical" else null end),
            confidence: (if $fixture == "critical-veto" then 1.0 else null end),
            reason: (if $fixture == "critical-veto" then "fixture: implementation plan lacks tests for a high-risk change" else null end),
            overridden: false
          },
          artifacts: {
            synthesis: "synthesis.md",
            responses_dir: "responses",
            critiques_dir: "critiques"
          },
          implementation: {
            permission: $implement,
            worktree: $worktree,
            gate_a_approved: false,
            gate_b_approved: false,
            handoff: null
          },
          fixture: (if $fixture == "" then null else $fixture end)
        }' > "$summary_path"
}

council_run() {
    if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        council_usage
        return 0
    fi

    council_parse_args "$@" || return $?

    if [[ -z "$COUNCIL_TASK" ]]; then
        council_error_usage "missing task"
        return 2
    fi

    council_create_run_dir || return 1

    if [[ "$COUNCIL_DRY_RUN" == "true" ]]; then
        council_write_summary_json "dry-run" || return 1
        if [[ "$COUNCIL_JSON" == "true" ]]; then
            cat "${COUNCIL_RUN_DIR}/summary.json"
        else
            echo "Council dry run complete: ${COUNCIL_RUN_DIR}/summary.json"
        fi
        return 0
    fi

    council_write_summary_json "partial" || return 1
    echo "Council first slice is installed. Use --dry-run for deterministic preflight until provider fanout ships."
}
