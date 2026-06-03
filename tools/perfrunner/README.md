# perfrunner

Performance measurement harness for DMD. Given two already-built `dmd`
binaries (a base and a head), it runs the Phase A workload, measures it, and
writes a `results.json`. The GitHub workflow builds the two compilers; this
tool only measures — it never touches git.

This is **Phase A (MVP)**: a single committed `hello.d` workload and the five
metrics below. The data repo and dashboard are later phases.

## Usage

```
dub run perfrunner -- \
  --base-dmd <path> --head-dmd <path> \
  --base-sha <sha>  --head-sha <sha> \
  [--pr <number>]   --out results.json
```

- `--base-dmd` / `--head-dmd`: paths to the two already-built compilers.
- `--base-sha` / `--head-sha` / `--pr`: metadata, copied into the report.
- `--os` / `--host-dmd`: runner metadata for the report (default
  `ubuntu-latest`, host dmd version blank).
- `--out`: where to write `results.json` (default `results.json`).

Requires `valgrind`, `strip`, and GNU `/usr/bin/time -v` on the PATH (Linux).

## Metrics (Phase A)

| id | what | tool |
|----|------|------|
| `compile_hello_debug_instr`   | instructions to compile `hello.d`           | cachegrind |
| `compile_hello_release_instr` | instructions to compile `hello.d -O -release` | cachegrind |
| `dmd_binary_size`             | stripped size of the `dmd` binary           | stat |
| `hello_binary_size`           | stripped size of the `hello` executable     | stat |
| `hello_max_rss`               | peak RSS compiling `hello.d`                | time -v |

## Layout

- `source/app.d` — CLI entry: parse args, measure, write `results.json`.
- `source/runner.d` — shell-out helper: run a command, capture output.
- `source/cachegrind.d` — wrap valgrind, parse `I refs:`.
- `source/metrics.d` — the five Phase A metric definitions.
- `source/stats.d` — `% delta` helper.
- `source/report.d` — `results.json` schema v1.
- `source/workloads/hello.d` — the committed Phase A workload.

## Tests

```
dub test
```

Covers stats, cachegrind/`time -v` parsing, and report serialisation.
