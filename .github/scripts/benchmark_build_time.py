#!/usr/bin/env python3

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path


def run(cmd, *, cwd=None, env=None, capture_output=False):
    print(f"+ {' '.join(cmd)}", flush=True)
    return subprocess.run(
        cmd,
        cwd=cwd,
        env=env,
        text=True,
        capture_output=capture_output,
        check=True,
    )


def create_worktree(repo_root: Path, sha: str, destination: Path):
    if destination.exists():
        shutil.rmtree(destination)
    run(["git", "worktree", "add", "--detach", str(destination), sha], cwd=repo_root)


def remove_worktree(repo_root: Path, destination: Path):
    subprocess.run(["git", "worktree", "remove", "--force", str(destination)], cwd=repo_root, check=False)
    if destination.exists():
        shutil.rmtree(destination)


def host_dmd_from_environment() -> str:
    for candidate in ("DMD", "DC"):
        value = os.environ.get(candidate)
        if value:
            return value
    return "dmd"


def benchmark_build(worktree: Path, *, label: str, sha: str, base_branch: str):
    env = os.environ.copy()
    env.setdefault("N", "2")
    env.setdefault("MODEL", "64")
    env.setdefault("HOST_DMD", host_dmd_from_environment())
    host_dmd = env["HOST_DMD"]

    if (worktree / "generated").exists():
        shutil.rmtree(worktree / "generated")

    bootstrap_command = [host_dmd, "compiler/src/build.d", "-ofgenerated/build"]
    command = [
        "generated/build",
        f"-j{env['N']}",
        f"MODEL={env['MODEL']}",
        f"HOST_DMD={host_dmd}",
        "dmd",
    ]

    started = time.perf_counter()
    run(bootstrap_command, cwd=worktree, env=env)
    run(command, cwd=worktree, env=env)
    elapsed_seconds = time.perf_counter() - started

    return {
        "benchmark": "dmd-compiler-build",
        "label": label,
        "sha": sha,
        "base_branch": base_branch,
        "host_dmd": host_dmd,
        "model": env["MODEL"],
        "jobs": int(env["N"]),
        "commands": [bootstrap_command, command],
        "elapsed_seconds": elapsed_seconds,
    }


def write_json(path: Path, payload):
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def format_seconds(value: float) -> str:
    return f"{value:.3f}s"


def build_comment(base_result, head_result, *, base_label: str, head_label: str):
    base_seconds = base_result["elapsed_seconds"]
    head_seconds = head_result["elapsed_seconds"]
    delta_seconds = head_seconds - base_seconds
    delta_percent = (delta_seconds / base_seconds * 100.0) if base_seconds else 0.0

    if abs(delta_percent) < 0.5:
        verdict = "no meaningful change"
        emoji = "⚪"
    elif delta_seconds < 0:
        verdict = "faster"
        emoji = "🟢"
    else:
        verdict = "slower"
        emoji = "🔴"

    sign = "+" if delta_seconds >= 0 else ""
    marker = "<!-- augment-dmd-build-time-bot -->"
    lines = [
        marker,
        "## Build Time Comparison",
        "",
        f"{emoji} Head is **{verdict}** than base.",
        "",
        "| Version | Commit | Build time |",
        "| --- | --- | ---: |",
        f"| {base_label} | `{base_result['sha'][:12]}` | {format_seconds(base_seconds)} |",
        f"| {head_label} | `{head_result['sha'][:12]}` | {format_seconds(head_seconds)} |",
        "",
        f"**Delta:** `{sign}{delta_seconds:.3f}s` ({sign}{delta_percent:.2f}%)",
        "",
        "Measured metric: compiler build bootstrap + `generated/build ... dmd` on Linux x64 using the same workflow job.",
    ]
    return "\n".join(lines) + "\n", {
        "benchmark": "dmd-compiler-build",
        "base": base_result,
        "head": head_result,
        "delta_seconds": delta_seconds,
        "delta_percent": delta_percent,
        "verdict": verdict,
    }


def main():
    parser = argparse.ArgumentParser(description="Benchmark DMD compiler build time for two commits.")
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--base-sha", required=True)
    parser.add_argument("--head-sha", required=True)
    parser.add_argument("--base-branch", required=True)
    parser.add_argument("--base-label", default="base")
    parser.add_argument("--head-label", default="head")
    parser.add_argument("--output-dir", required=True)
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    output_dir = Path(args.output_dir).resolve()
    workspace_parent = repo_root.parent
    output_dir.mkdir(parents=True, exist_ok=True)

    base_worktree = workspace_parent / "perf-base-worktree"
    head_worktree = workspace_parent / "perf-head-worktree"

    try:
        create_worktree(repo_root, args.base_sha, base_worktree)
        create_worktree(repo_root, args.head_sha, head_worktree)

        base_result = benchmark_build(
            base_worktree,
            label=args.base_label,
            sha=args.base_sha,
            base_branch=args.base_branch,
        )
        head_result = benchmark_build(
            head_worktree,
            label=args.head_label,
            sha=args.head_sha,
            base_branch=args.base_branch,
        )

        comment_markdown, comparison = build_comment(
            base_result,
            head_result,
            base_label=args.base_label,
            head_label=args.head_label,
        )

        write_json(output_dir / "base.json", base_result)
        write_json(output_dir / "head.json", head_result)
        write_json(output_dir / "comparison.json", comparison)
        (output_dir / "comment.md").write_text(comment_markdown, encoding="utf-8")

    finally:
        remove_worktree(repo_root, base_worktree)
        remove_worktree(repo_root, head_worktree)


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as exc:
        if exc.stdout:
            sys.stdout.write(exc.stdout)
        if exc.stderr:
            sys.stderr.write(exc.stderr)
        raise