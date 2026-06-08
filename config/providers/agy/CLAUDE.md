# Antigravity CLI Provider

Antigravity CLI (`agy`) is a first-class external CLI provider.

## Detection

```bash
command -v agy
```

## Dispatch

Prompts are delivered through stdin and executed with Antigravity print mode:

```bash
agy --print --sandbox --print-timeout "${OCTOPUS_AGY_PRINT_TIMEOUT:-5m0s}" --model "${OCTOPUS_AGY_MODEL:-Claude Sonnet 4.6 (Thinking)}"
```

Octopus dispatches through `scripts/helpers/agy-exec.sh` so Antigravity display
model names with spaces are passed as a single argv element. The default model is
`Claude Sonnet 4.6 (Thinking)` because it produces reliable non-interactive
output in current `agy` releases.

Set `OCTOPUS_AGY_MODEL=default` to omit `--model` and use the Antigravity CLI
default. Set `OCTOPUS_AGY_PRINT_TIMEOUT` to override the print-mode wait time.

When `OCTOPUS_AGY_MODEL` is non-empty and not `default`, Octopus adds:

```bash
--model "$OCTOPUS_AGY_MODEL"
```

## Notes

- `agy` is not treated as a Gemini CLI wrapper.
- Gemini-specific flags such as `-o text`, `--approval-mode yolo`, and the
  Gemini fallback helper are not used for Antigravity.
- Antigravity currently inherits the parent shell environment instead of the
  stripped `env -i` provider environment because current `agy` releases rely on
  desktop/session context for auth and prompt-mode behavior. Avoid exporting
  secrets that are not needed by local CLI tools before running `agy` workflows.
- `agy --print-timeout` is the primary timeout for Antigravity print mode.
- This provider was added in response to #423.
