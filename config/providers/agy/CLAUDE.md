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

## Security Note

By default, Antigravity (`agy`) inherits the parent shell environment instead of
running under the stripped `env -i` environment used by some other providers.
That means `agy` can see all exported environment variables in the shell that
starts Octopus.

Avoid exporting secrets that are not needed by local CLI tools before running
`agy` workflows. If you are unsure what is currently exported, check with a
command such as:

```bash
env | grep -Ei 'secret|token|key'
```

For stricter isolation, run Octopus with `OCTOPUS_AGY_ISOLATED=true`. In that
mode, Octopus starts `agy` with a minimal environment (`HOME`, `PATH`, `TERM`,
`TMPDIR`, trace headers, and optional `AGY_AUTH_TOKEN`/`AGY_CONFIG` values).
Keep `OCTOPUS_AGY_PRINT_TIMEOUT` set high enough for isolated print-mode runs if
your selected model needs more time.

## Notes

- `agy` is not treated as a Gemini CLI wrapper.
- Gemini-specific flags such as `-o text`, `--approval-mode yolo`, and the
  Gemini fallback helper are not used for Antigravity.
- `agy --print-timeout` is the primary timeout for Antigravity print mode.
- This provider was added in response to #423.
