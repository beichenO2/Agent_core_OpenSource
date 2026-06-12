#!/usr/bin/env python3
"""Scan all polaris.json for not-done features and rank by priority signals."""
import json
import os
import sys
from pathlib import Path

ROOT = Path("~/Polarisor")
NOT_DONE = {"in_progress", "in-progress", "pending", "todo", "blocked", "planned"}


def main():
    rows = []
    for entry in sorted(ROOT.iterdir()):
        if not entry.is_dir() or entry.name.startswith("tqsdk-gnhf-worktrees"):
            continue
        polaris = entry / "polaris.json"
        if not polaris.exists():
            continue
        try:
            data = json.loads(polaris.read_text())
        except Exception:
            continue
        for r in data.get("requirements", []):
            for f in r.get("features", []):
                status = f.get("status", "")
                if status in NOT_DONE:
                    rows.append({
                        "project": entry.name,
                        "req_id": r.get("id"),
                        "req_name": r.get("name") or r.get("need") or "?",
                        "feature_name": f.get("name", "?"),
                        "status": status,
                        "test_status": f.get("test_status", ""),
                        "description": f.get("description", "") or "",
                        "behavior": f.get("behavior", []) if isinstance(f.get("behavior", []), list) else [str(f.get("behavior"))],
                    })

    print(f"Found {len(rows)} not-done features across {len(set(r['project'] for r in rows))} projects\n")
    print("=" * 80)
    print("not-done features (sorted by project)")
    print("=" * 80)
    for r in rows:
        bhead = r['behavior'][0] if r['behavior'] else r['description']
        print(f"\n[{r['project']}] {r['req_id']} {r['req_name']}")
        print(f"  feature: {r['feature_name']} (status={r['status']}, test={r['test_status']})")
        if r['description']:
            print(f"  desc: {r['description'][:120]}")
        if r['behavior']:
            print(f"  behavior[0]: {bhead[:120]}")

    print("\n" + "=" * 80)
    print("PROJECT SUMMARY")
    print("=" * 80)
    by_proj = {}
    for r in rows:
        by_proj.setdefault(r['project'], []).append(r)
    for p, lst in sorted(by_proj.items()):
        print(f"  {p}: {len(lst)} features")


if __name__ == "__main__":
    main()
