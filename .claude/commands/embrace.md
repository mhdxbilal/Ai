---
command: embrace
description: "Full Double Diamond workflow - Research -> Define -> Develop -> Deliver"
aliases:
  - full-cycle
  - complete-workflow
---

# Embrace - Complete Double Diamond Workflow

**Your first output line MUST be:** `🐙 Octopus Embrace`

## Mandatory Contract

`/octo:embrace` is a runner-driven workflow. Claude may collect user preferences
and summarize artifacts, but it must not execute phases manually or substitute
local implementation work for a failed phase.

Forbidden during an Embrace run:
- Running Discover, Define, Develop, or Deliver as separate ad hoc steps.
- Implementing code directly after a failed Develop/Tangle phase.
- Treating a chat debate as a gate unless an `embrace-gate-*.md` artifact exists.
- Reporting success from narrative memory instead of runner artifacts.

## Step 1: Ask Clarifying Questions

Use `AskUserQuestion` to collect:
- scope: small, medium, large, or full system
- focus areas: architecture, security, performance, user experience
- autonomy: supervised, semi-autonomous, autonomous, or manual
- debate gates: none, Define->Develop, both gates, or only on disagreement

If running in a remote/cloud session, default to autonomous and infer scope/focus
from the prompt unless the user provided explicit choices.

## Step 2: Check Provider Availability

Run the provider checker before starting the workflow:

```bash
bash "${HOME}/.claude-octopus/plugin/scripts/helpers/check-providers.sh"
```

Display the actual provider status from that command. Do not replace it with an
inline provider check.

## Step 3: Run The Single Embrace Runner

Map the debate answer to `OCTOPUS_DEBATE_GATES`:
- none -> `none`
- Define->Develop -> `define`
- both gates -> `both`
- only on disagreement -> `auto`

Then run exactly one Embrace runner command:

```bash
cd "${HOME}/.claude-octopus/plugin" && OCTOPUS_DEBATE_GATES="<mapped-value>" bash scripts/orchestrate.sh embrace "<user prompt>"
```

The runner owns all phase transitions, required artifacts, debate-gate artifacts,
and failure stops.

## Step 4: Present Runner Artifacts

After the runner exits, summarize only what the artifacts prove:
- `probe-synthesis-*.md`
- `grasp-consensus-*.md`
- `embrace-gate-*.md` when requested
- `tangle-validation-*.md`
- `delivery-*.md`

If the runner exits non-zero, report the failed phase and stop. Do not continue manually unless the user explicitly starts a separate non-Embrace task.
