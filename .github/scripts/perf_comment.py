#!/usr/bin/env python3
"""Render the perfrunner results.json into a sticky PR comment.

also upserts a single comment identified by a hidden marker so
pushes update one comment instead of spamming.
"""

import json
import os
import sys
import urllib.request

MARKER = "<!-- dmd-perf-bot -->"
THRESHOLDS = {"cachegrind": 0.1, "stat": 0.1, "time -v": 2.0}


def fmt_value(value, unit):
    if unit == "count":
        return f"{value / 1e6:,.1f} M"
    if unit == "bytes":
        return f"{value / (1024 * 1024):.2f} MB"
    if unit == "kb":
        return f"{value / 1024:.0f} MB"
    return str(value)


def fmt_delta(pct):
    value = f"{abs(pct):.2f}"
    if value == "0.00":
        return "0.00%"
    sign = "+" if pct > 0 else "-"
    return f"{sign}{value}%"


def fmt_share(value, total):
    if total <= 0:
        return "n/a"
    return f"{value / total * 100:.0f}%"


def is_significant(m):
    return abs(m["delta_pct"]) >= THRESHOLDS.get(m["method"], 0.1)


# Stage rows (frontend/backend) shown as base%/head% shares of their group.
def breakdown(children):
    base_total = sum(c["base"] for c in children)
    head_total = sum(c["head"] for c in children)
    if head_total <= 0:
        return []
    return ["| ↳ {} | {} | {} | {} |".format(
        c["label"],
        fmt_share(c["base"], base_total),
        fmt_share(c["head"], head_total),
        fmt_delta(c["delta_pct"]),
    ) for c in children]


def render(results):
    lines = [
        MARKER,
        "### DMD perf check",
        "",
        "| Metric | Base | PR | delta |",
        "|--------|------|----|-------|",
    ]
    metrics = results["metrics"]
    for m in metrics:
        if m.get("parent"):
            continue
        lines.append("| {} | {} | {} | {} |".format(
            m["label"],
            fmt_value(m["base"], m["unit"]),
            fmt_value(m["head"], m["unit"]),
            fmt_delta(m["delta_pct"]),
        ))
        children = [c for c in metrics if c.get("parent") == m["id"]]
        if children and is_significant(m):
            lines += breakdown(children)
    return "\n".join(lines) + "\n"


def api(method, url, token, payload=None):
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Accept", "application/vnd.github+json")
    if data:
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read() or "null")


def upsert(body, repo, pr, token):
    base = f"https://api.github.com/repos/{repo}"
    comments = api("GET", f"{base}/issues/{pr}/comments?per_page=100", token)
    existing = next((c for c in comments if MARKER in (c.get("body") or "")), None)
    if existing:
        api("PATCH", f"{base}/issues/comments/{existing['id']}", token, {"body": body})
    else:
        api("POST", f"{base}/issues/{pr}/comments", token, {"body": body})


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: perf_comment.py results.json")

    with open(sys.argv[1]) as f:
        results = json.load(f)

    body = render(results)
    print(body)

    token = os.environ.get("GITHUB_TOKEN")
    repo = os.environ.get("REPO")
    # workflow_run has no PR context, so fall back to the number in results.json.
    pr = os.environ.get("PR_NUMBER") or results["head"].get("pr")
    if not token or not repo or not pr:
        return

    significant = any(
        is_significant(m) for m in results["metrics"] if not m.get("parent")
    )
    if not significant:
        print("all deltas within noise threshold, skipping comment")
        return

    upsert(body, repo, pr, token)
    print(f"upserted comment on {repo}#{pr}")


if __name__ == "__main__":
    main()
