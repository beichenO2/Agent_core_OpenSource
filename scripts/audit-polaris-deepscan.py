#!/usr/bin/env python3
"""Deep scan all polaris.json + git status across Polarisor projects."""
import json
import os
import subprocess
from pathlib import Path

ROOT = Path("~/Polarisor")
EXCLUDE_DIRS = {"tqsdk-gnhf-worktrees", "Desktop", "tqsdk-gnhf-worktrees-old"}

# Required fields (top-level)
REQUIRED = ["name", "description", "status", "version"]
RECOMMENDED = ["tier", "contacts", "requirements"]


def find_projects():
    projects = []
    for entry in sorted(ROOT.iterdir()):
        if not entry.is_dir() or entry.name.startswith("."):
            continue
        polaris = entry / "polaris.json"
        if polaris.exists():
            projects.append(entry)
    return projects


def git_info(project_dir):
    info = {"git": False}
    git_dir = project_dir / ".git"
    if not git_dir.exists():
        return info
    info["git"] = True
    try:
        info["branch"] = subprocess.check_output(
            ["git", "branch", "--show-current"], cwd=project_dir, text=True
        ).strip()
        info["commits_ahead_of_main"] = (
            subprocess.check_output(
                ["git", "rev-list", "--count", "main..HEAD"],
                cwd=project_dir, text=True, stderr=subprocess.DEVNULL
            ).strip()
            if info["branch"] != "main" else "0"
        )
        info["uncommitted"] = bool(
            subprocess.check_output(
                ["git", "status", "--short"], cwd=project_dir, text=True
            ).strip()
        )
        try:
            info["remote"] = subprocess.check_output(
                ["git", "config", "--get", "remote.origin.url"],
                cwd=project_dir, text=True, stderr=subprocess.DEVNULL
            ).strip()
        except subprocess.CalledProcessError:
            info["remote"] = None
        info["last_commit"] = subprocess.check_output(
            ["git", "log", "--oneline", "-1"], cwd=project_dir, text=True
        ).strip()
    except subprocess.CalledProcessError as e:
        info["error"] = str(e)
    return info


def scan_polaris(polaris_path):
    try:
        data = json.loads(polaris_path.read_text())
    except Exception as e:
        return {"error": f"parse: {e}"}
    issues = []
    has = {f: f in data for f in REQUIRED + RECOMMENDED}

    if not data.get("status"):
        issues.append("missing_top_level_status")
    if not data.get("name") and not data.get("project_name"):
        issues.append("missing_name")
    if not data.get("description"):
        issues.append("missing_description")
    if not data.get("version"):
        issues.append("missing_version")
    if "requirements" not in data:
        issues.append("missing_requirements")
    if "contacts" not in data:
        issues.append("missing_contacts")
    if "tier" not in data:
        issues.append("missing_tier")

    reqs = data.get("requirements", [])
    feature_count = 0
    not_done_features = 0
    for r in reqs:
        for f in r.get("features", []):
            feature_count += 1
            if f.get("status") not in ("done", "passed"):
                not_done_features += 1
            if "test_status" not in f:
                issues.append(f"feature_missing_test_status:{r.get('id')}/{f.get('name','?')}")

    return {
        "ok": not issues,
        "status_value": data.get("status"),
        "version": data.get("version"),
        "tier": data.get("tier"),
        "n_requirements": len(reqs),
        "n_features": feature_count,
        "not_done_features": not_done_features,
        "issues": issues,
        "has_fields": has,
    }


def main():
    projects = find_projects()
    print(f"Scanned {len(projects)} projects with polaris.json:\n")
    rows = []
    for p in projects:
        polaris = p / "polaris.json"
        scan = scan_polaris(polaris)
        gi = git_info(p)
        rows.append((p.name, scan, gi))

    print("=" * 100)
    for name, scan, gi in rows:
        print(f"\n## {name}")
        print(f"  status: {scan.get('status_value')}  version: {scan.get('version')}  tier: {scan.get('tier')}")
        print(f"  requirements: {scan.get('n_requirements')}  features: {scan.get('n_features')}  not_done: {scan.get('not_done_features')}")
        if scan.get("issues"):
            print(f"  ISSUES: {scan['issues'][:5]}{'...' if len(scan['issues']) > 5 else ''}")
        if gi.get("git"):
            badge = "OK" if gi["branch"] == "main" else "OFF-MAIN"
            uncommitted = " UNCOMMITTED" if gi.get("uncommitted") else ""
            ahead = f" (+{gi.get('commits_ahead_of_main')} ahead)" if gi.get("branch") != "main" else ""
            print(f"  git: {badge} {gi['branch']}{ahead}{uncommitted}")
            if gi.get("remote"):
                print(f"       remote: {gi['remote']}")
            else:
                print(f"       remote: (none, local-only)")

    print("\n" + "=" * 100)
    print("\nSUMMARY:")
    crit = [r for r in rows if r[1].get("issues")]
    off_main = [r for r in rows if r[2].get("git") and r[2].get("branch") != "main"]
    uncommitted = [r for r in rows if r[2].get("git") and r[2].get("uncommitted")]
    print(f"  projects_with_polaris_issues: {len(crit)}")
    for name, scan, _ in crit:
        print(f"    - {name}: {scan['issues'][:3]}")
    print(f"  projects_off_main: {len(off_main)}")
    for name, _, gi in off_main:
        print(f"    - {name}: branch={gi['branch']} ahead={gi.get('commits_ahead_of_main')}")
    print(f"  projects_with_uncommitted: {len(uncommitted)}")
    for name, _, gi in uncommitted:
        print(f"    - {name}")


if __name__ == "__main__":
    main()
