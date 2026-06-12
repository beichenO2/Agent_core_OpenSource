#!/usr/bin/env python3
"""
Two-in-one scan:
1) SSoT drift: _Polarisor/projects.md mentions vs actual ~/Polarisor/<dirs> with polaris.json
2) evidence/interfaces field reality check inside each polaris.json
"""
import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path("~/Polarisor")


def find_actual_projects():
    """Each direct subdir with polaris.json (excluding worktrees)."""
    out = {}
    for entry in sorted(ROOT.iterdir()):
        if not entry.is_dir():
            continue
        if entry.name.startswith("tqsdk-gnhf-worktrees"):
            continue
        polaris = entry / "polaris.json"
        if polaris.exists():
            try:
                data = json.loads(polaris.read_text())
                name = data.get("name") or data.get("project_name") or entry.name
                out[entry.name] = {
                    "dir": entry.name,
                    "polaris_name": name,
                    "polaris_path": str(polaris),
                    "data": data,
                }
            except Exception as e:
                out[entry.name] = {"error": str(e), "polaris_path": str(polaris)}
    return out


def parse_projects_md_names(projects_md_path):
    """Extract project names listed in _Polarisor/projects.md table."""
    text = projects_md_path.read_text()
    # find lines like: | 1 | SOTAgent | beichenO2/SOTAgent | ...
    rows = re.findall(r"^\|\s*\d+\s*\|\s*([^|]+?)\s*\|", text, re.MULTILINE)
    cleaned = [r.strip() for r in rows]
    return [r for r in cleaned if r and r != "项目"]


def check_drift(actual, listed_names):
    """Compare actual project dirs vs names listed in projects.md."""
    actual_dir_names = set(actual.keys())
    listed_set = set(listed_names)
    missing_from_listing = actual_dir_names - listed_set
    extra_in_listing = listed_set - actual_dir_names
    return missing_from_listing, extra_in_listing


def evidence_check(project_dir, data):
    """For each feature.evidence entry, verify file paths and git hashes."""
    issues = []
    project_root = ROOT / project_dir
    for r in data.get("requirements", []):
        for f in r.get("features", []):
            evidences = f.get("evidence", [])
            if isinstance(evidences, str):
                evidences = [evidences]
            for evi in evidences:
                # match git hash (7-40 chars hex)
                git_hashes = re.findall(r"\bgit\s+([0-9a-f]{7,40})\b", evi)
                for h in git_hashes:
                    try:
                        result = subprocess.run(
                            ["git", "cat-file", "-e", h],
                            cwd=project_root,
                            capture_output=True,
                            timeout=5
                        )
                        if result.returncode != 0:
                            issues.append(f"{r.get('id')}/{f.get('name')}: git hash {h} not found in {project_dir}")
                    except (subprocess.TimeoutExpired, FileNotFoundError):
                        pass
                # match commit hash bare (PolarPilot bb93cbf style)
                bare_hashes = re.findall(r"\b(?:Commit|commit):\s+([0-9a-f]{7,40})\b", evi)
                for h in bare_hashes:
                    try:
                        result = subprocess.run(
                            ["git", "cat-file", "-e", h],
                            cwd=project_root,
                            capture_output=True,
                            timeout=5
                        )
                        if result.returncode != 0:
                            issues.append(f"{r.get('id')}/{f.get('name')}: commit {h} not found in {project_dir}")
                    except (subprocess.TimeoutExpired, FileNotFoundError):
                        pass
    return issues


def interfaces_check(project_dir, data):
    """For each feature.interfaces entry, verify route exists in code."""
    issues = []
    project_root = ROOT / project_dir
    for r in data.get("requirements", []):
        for f in r.get("features", []):
            interfaces = f.get("interfaces", [])
            for iface in interfaces:
                # match HTTP method + path: GET /api/foo  or POST /api/bar
                m = re.match(r"^(GET|POST|PATCH|DELETE|PUT)\s+(\S+)$", iface.strip())
                if not m:
                    continue
                method, path = m.groups()
                # quick grep: search for path literal in project source
                # remove path params like :id for grep
                pat = re.sub(r":[a-zA-Z_]+", "", path).rstrip("/").replace("/", "/")
                pat_short = pat.split("?")[0]
                try:
                    result = subprocess.run(
                        ["rg", "-l", "-e", pat_short[1:] if pat_short.startswith("/") else pat_short],
                        cwd=project_root,
                        capture_output=True,
                        text=True,
                        timeout=15
                    )
                    if result.returncode != 0 or not result.stdout.strip():
                        issues.append(f"{r.get('id')}/{f.get('name')}: {method} {path} not found in code")
                except (subprocess.TimeoutExpired, FileNotFoundError):
                    pass
    return issues


def run_scan():
    """Run the full drift + evidence/interfaces scan and return structured results."""
    actual = find_actual_projects()

    projects_md = ROOT / "_Polarisor" / "projects.md"
    if projects_md.exists():
        listed = parse_projects_md_names(projects_md)
    else:
        listed = []

    missing_from_listing, extra_in_listing = check_drift(actual, listed)

    evidence_issues_by_project = {}
    interface_issues_by_project = {}
    total_evidence_issues = 0
    total_interface_issues = 0

    for proj_name, info in actual.items():
        if "error" in info:
            continue
        e_issues = evidence_check(proj_name, info["data"])
        i_issues = interfaces_check(proj_name, info["data"])
        if e_issues:
            evidence_issues_by_project[proj_name] = e_issues
            total_evidence_issues += len(e_issues)
        if i_issues:
            interface_issues_by_project[proj_name] = i_issues
            total_interface_issues += len(i_issues)

    return {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "actualProjectsCount": len(actual),
        "listedProjectsCount": len(listed),
        "projectsNotInProjectsMd": sorted(missing_from_listing),
        "namesWithoutDirectory": sorted(extra_in_listing),
        "evidenceIssues": evidence_issues_by_project,
        "interfaceIssues": interface_issues_by_project,
        "summary": {
            "missing": len(missing_from_listing),
            "extra": len(extra_in_listing),
            "evidence": total_evidence_issues,
            "interfaces": total_interface_issues,
        },
    }


def print_text_result(result):
    """Print human-readable text to stdout (original behavior)."""
    print("=" * 80)
    print("PART 1: SSoT DRIFT CHECK")
    print("=" * 80)
    print(f"\nActual project dirs with polaris.json: {result['actualProjectsCount']}")

    print(f"\nProjects listed in _Polarisor/projects.md: {result['listedProjectsCount']}")

    print(f"\n## Drift")
    print(f"  Has polaris.json but NOT listed in projects.md ({result['summary']['missing']}):")
    for n in result["projectsNotInProjectsMd"]:
        print(f"    - {n}")
    print(f"  Listed in projects.md but no polaris.json or different dirname ({result['summary']['extra']}):")
    for n in result["namesWithoutDirectory"]:
        print(f"    - {n}")

    print()
    print("=" * 80)
    print("PART 2: evidence/interfaces FIELD REALITY CHECK")
    print("=" * 80)
    for proj, issues in result["evidenceIssues"].items():
        print(f"\n## {proj}")
        for x in issues:
            print(f"  [evidence] {x}")
    for proj, issues in result["interfaceIssues"].items():
        if proj not in result["evidenceIssues"]:
            print(f"\n## {proj}")
        for x in issues:
            print(f"  [interface] {x}")

    print()
    print("=" * 80)
    print(f"SUMMARY:")
    s = result["summary"]
    print(f"  SSoT drift: missing={s['missing']} extra={s['extra']}")
    print(f"  evidence/interfaces issues: evidence={s['evidence']} interfaces={s['interfaces']}")


def main():
    parser = argparse.ArgumentParser(description="SSoT drift and evidence/interfaces scanner")
    parser.add_argument("--output-file", help="Write structured JSON results to this path")
    args = parser.parse_args()

    result = run_scan()

    if args.output_file:
        out_path = Path(args.output_file)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(json.dumps(result, indent=2, ensure_ascii=False))
        print(f"SSoT drift audit results written to: {args.output_file}", file=sys.stderr)
    else:
        print_text_result(result)


if __name__ == "__main__":
    main()
