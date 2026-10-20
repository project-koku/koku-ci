#!/usr/bin/env python3
"""Re-trigger a Koku Konflux integration test.

The command is dry-run by default. Pass --yes after reviewing the resolved
PipelineRun and Snapshot to apply the Snapshot label that triggers the rerun.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
from typing import Any


DEFAULT_REPO = "project-koku/koku"
DEFAULT_NAMESPACE = "cost-mgmt-dev-tenant"
DEFAULT_SCENARIO = "koku-ci"
DEFAULT_CHECK_NAME = "Red Hat Konflux / koku-ci / koku"
DEFAULT_KUBEARCHIVE = "https://kubearchive-api-server-product-kubearchive.apps.stone-prd-rh01.pg1f.p1.openshiftapps.com"
DEFAULT_API_SERVER = "https://api.stone-prd-rh01.pg1f.p1.openshiftapps.com:6443"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))


class UserError(Exception):
    """An expected command or input error that should be shown without a stack."""


def parse_pr(value: str, default_repo: str = DEFAULT_REPO) -> tuple[str, str]:
    """Return (repo, pr_number) from a PR number or GitHub PR URL."""
    if re.fullmatch(r"\d+", value):
        return default_repo, value

    match = re.search(r"github\.com/([^/\s]+/[^/\s]+)/pull/(\d+)", value)
    if match:
        return match.group(1), match.group(2)

    match = re.fullmatch(r"([^/\s]+/[^#\s]+)#(\d+)", value)
    if match:
        return match.group(1), match.group(2)

    raise UserError(f"Could not parse PR {value!r}; use a number, GitHub PR URL, or owner/repo#number")


def extract_pipelinerun_name(*texts: str | None, scenario: str = DEFAULT_SCENARIO) -> str | None:
    """Find a PipelineRun name in URLs or free text."""
    joined = "\n".join(t for t in texts if t)
    match = re.search(r"/pipelineruns?/([A-Za-z0-9][A-Za-z0-9-]*)", joined)
    if match:
        return match.group(1)
    match = re.search(rf"\b({re.escape(scenario)}-[A-Za-z0-9-]+)\b", joined)
    if match:
        return match.group(1)
    match = re.search(r"\b(koku-[A-Za-z0-9-]+)\b", joined)
    return match.group(1) if match else None


def select_integration_check(
    checks: list[dict[str, Any]],
    check_name: str | None = None,
    scenario: str = DEFAULT_SCENARIO,
) -> dict[str, Any]:
    """Return the most useful failed integration check run from GitHub check-run data."""
    failed = {
        "failure",
        "timed_out",
        "action_required",
        "cancelled",
        "startup_failure",
        "stale",
    }
    if check_name:
        exact = [c for c in checks if c.get("name") == check_name and c.get("conclusion") in failed]
        if exact:
            return exact[0]
    loose = [
        c
        for c in checks
        if scenario in str(c.get("name", "")) and c.get("conclusion") in failed
    ]
    if loose:
        return loose[0]
    names = ", ".join(sorted({str(c.get("name")) for c in checks if c.get("name")}))
    target = repr(check_name) if check_name else f"scenario {scenario!r}"
    raise UserError(
        f"Could not find a failed check run for {target}. "
        f"Available checks: {names}"
    )


def snapshot_from_pipelinerun(item: dict[str, Any]) -> str | None:
    labels = item.get("metadata", {}).get("labels", {})
    return labels.get("appstudio.openshift.io/snapshot") or labels.get(
        "test.appstudio.openshift.io/snapshot"
    )


def run_json(command: list[str], env: dict[str, str] | None = None) -> dict[str, Any]:
    result = subprocess.run(command, capture_output=True, text=True, check=False, env=env)
    if result.returncode:
        detail = result.stderr.strip() or result.stdout.strip() or "command failed"
        raise UserError(f"{' '.join(command)} failed: {detail}")
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise UserError(f"{' '.join(command)} did not return JSON: {error}") from error


def run_text(command: list[str], env: dict[str, str] | None = None) -> str:
    result = subprocess.run(command, capture_output=True, text=True, check=False, env=env)
    if result.returncode:
        detail = result.stderr.strip() or result.stdout.strip() or "command failed"
        raise UserError(f"{' '.join(command)} failed: {detail}")
    return result.stdout.strip()


def require_command(name: str) -> None:
    if shutil.which(name) is None:
        raise UserError(f"{name} CLI is required and was not found in PATH")


def kube_env(kubeconfig: str | None) -> dict[str, str]:
    if not kubeconfig:
        return os.environ.copy()
    return os.environ | {"KUBECONFIG": os.path.expanduser(kubeconfig)}


def login_hint(api_server: str, kubeconfig: str | None) -> str:
    if kubeconfig:
        command = f"KUBECONFIG={kubeconfig} oc login --web {api_server}"
        return "Not logged in to Konflux. Run:\n  " + command
    return (
        "Not logged in to Konflux. Run:\n"
        f"  cd {SCRIPT_DIR}\n"
        "  make login\n"
        "  eval $(make env)\n"
        f"Or run directly:\n  oc login --web {api_server}"
    )


def fetch_check_runs(repo: str, sha: str) -> list[dict[str, Any]]:
    data = run_json(
        [
            "gh",
            "api",
            "--paginate",
            "--slurp",
            f"/repos/{repo}/commits/{sha}/check-runs?per_page=100",
        ]
    )
    if isinstance(data, list):
        runs: list[dict[str, Any]] = []
        for page in data:
            if isinstance(page, dict):
                runs.extend(page.get("check_runs", []))
        return runs
    return data.get("check_runs", [])


def resolve_pr_to_pipelinerun(pr: str, repo: str, check_name: str | None, scenario: str) -> tuple[dict[str, Any], str]:
    require_command("gh")
    repo, number = parse_pr(pr, default_repo=repo)
    pr_data = run_json(["gh", "pr", "view", number, "-R", repo, "--json", "headRefOid,number,url"])
    sha = pr_data.get("headRefOid")
    if not sha:
        raise UserError(f"Could not resolve the head SHA for {repo}#{number}")
    check = select_integration_check(fetch_check_runs(repo, sha), check_name=check_name, scenario=scenario)
    output = check.get("output") or {}
    pipelinerun = extract_pipelinerun_name(
        check.get("details_url"),
        check.get("html_url"),
        output.get("title"),
        output.get("summary"),
        output.get("text"),
        scenario=scenario,
    )
    if not pipelinerun:
        raise UserError(
            f"Found the failed {scenario} check, but could not extract a PipelineRun name. "
            "Open the check details and rerun with --pipelinerun <name>."
        )
    return {"repo": repo, "number": str(pr_data.get("number") or number), "url": pr_data.get("url"), "check": check}, pipelinerun


def get_live_pipelinerun(name: str, namespace: str, env: dict[str, str]) -> dict[str, Any] | None:
    result = subprocess.run(
        ["oc", "get", "pipelinerun", name, "-n", namespace, "-o", "json"],
        capture_output=True,
        text=True,
        check=False,
        env=env,
    )
    if result.returncode:
        return None
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return None


def oc_token(env: dict[str, str]) -> str:
    result = subprocess.run(["oc", "whoami", "-t"], capture_output=True, text=True, check=False, env=env)
    if result.returncode or not result.stdout.strip():
        raise UserError(login_hint(env.get("KOKU_CI_RERUN_API_SERVER", DEFAULT_API_SERVER), env.get("KOKU_CI_RERUN_KUBECONFIG")))
    return result.stdout.strip()


def get_archived_pipelinerun(
    name: str,
    namespace: str,
    kubearchive: str,
    env: dict[str, str],
) -> dict[str, Any] | None:
    token = oc_token(env)
    path = f"/apis/tekton.dev/v1/namespaces/{namespace}/pipelineruns/{name}"
    request = urllib.request.Request(
        kubearchive.rstrip("/") + path,
        headers={"Authorization": f"Bearer {token}", "Accept": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.loads(response.read())
    except urllib.error.HTTPError as error:
        if error.code in {404, 410}:
            return None
        if error.code == 401:
            hint = login_hint(
                env.get("KOKU_CI_RERUN_API_SERVER", DEFAULT_API_SERVER),
                env.get("KOKU_CI_RERUN_KUBECONFIG"),
            )
            raise UserError("The Konflux token was rejected by KubeArchive. " + hint) from None
        raise UserError(f"KubeArchive lookup for {name} failed with HTTP {error.code}") from None
    except (urllib.error.URLError, json.JSONDecodeError) as error:
        raise UserError(f"KubeArchive lookup for {name} failed: {error}") from error


def resolve_pipelinerun_to_snapshot(
    name: str,
    namespace: str,
    kubearchive: str,
    env: dict[str, str],
) -> tuple[str, str]:
    item = get_live_pipelinerun(name, namespace, env)
    source = "live cluster"
    if item is None:
        item = get_archived_pipelinerun(name, namespace, kubearchive, env)
        source = "KubeArchive"
    if item is None:
        raise UserError(
            f"Could not find PipelineRun {name!r} in the live cluster or KubeArchive. "
            "Pass --snapshot if you already know it."
        )
    snapshot = snapshot_from_pipelinerun(item)
    if not snapshot:
        raise UserError(f"PipelineRun {name!r} does not have an appstudio Snapshot label")
    return snapshot, source


def label_snapshot(snapshot: str, scenario: str, namespace: str, env: dict[str, str]) -> None:
    try:
        run_text(
            [
                "oc",
                "label",
                "snapshot",
                snapshot,
                f"test.appstudio.openshift.io/run={scenario}",
                "-n",
                namespace,
                "--overwrite",
            ],
            env=env,
        )
    except UserError as error:
        message = str(error)
        if "snapshots.appstudio.redhat.com" in message and "not found" in message.lower():
            raise UserError(
                message
                + "\n\nThe Snapshot may have been pruned by Konflux. For older PRs, comment "
                + "`/ok-to-test` on the PR to create a fresh Snapshot instead."
            ) from None
        raise


def list_matching_runs(snapshot: str, scenario: str, namespace: str, env: dict[str, str]) -> str:
    selector = (
        f"test.appstudio.openshift.io/scenario={scenario},"
        f"appstudio.openshift.io/snapshot={snapshot}"
    )
    result = subprocess.run(
        ["oc", "get", "pipelineruns", "-n", namespace, "-l", selector, "--sort-by=.metadata.creationTimestamp"],
        capture_output=True,
        text=True,
        check=False,
        env=env,
    )
    return result.stdout.strip() if result.returncode == 0 else ""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    target = parser.add_mutually_exclusive_group(required=True)
    target.add_argument("--pr", help="GitHub PR number or URL, e.g. 6385")
    target.add_argument("--pipelinerun", help="Konflux PipelineRun name, e.g. koku-ci-h2bzj")
    target.add_argument("--snapshot", help="Konflux Snapshot name, e.g. koku-20261016-094306-000")
    parser.add_argument("--repo", default=DEFAULT_REPO, help=f"GitHub repo for --pr numbers (default: {DEFAULT_REPO})")
    parser.add_argument("--namespace", default=DEFAULT_NAMESPACE, help=f"Konflux namespace (default: {DEFAULT_NAMESPACE})")
    parser.add_argument(
        "--scenario",
        default=DEFAULT_SCENARIO,
        help=(
            f"IntegrationTestScenario to rerun (default: {DEFAULT_SCENARIO}); "
            "for example koku-enterprise-contract"
        ),
    )
    parser.add_argument(
        "--check-name",
        help=(
            "Specific GitHub check-run name to find for --pr. By default, "
            "select the failed check whose name contains --scenario."
        ),
    )
    parser.add_argument(
        "--api-server",
        default=DEFAULT_API_SERVER,
        help=f"Konflux cluster API URL for login hints (default: {DEFAULT_API_SERVER})",
    )
    parser.add_argument("--kubeconfig", help="Optional kubeconfig path. By default, use the active oc context.")
    parser.add_argument("--kubearchive", default=DEFAULT_KUBEARCHIVE, help="KubeArchive API server URL")
    parser.add_argument("--yes", action="store_true", help="Apply the Snapshot label. Without this, only print what would happen.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.yes or not args.snapshot:
        require_command("oc")
    env = kube_env(args.kubeconfig)
    env["KOKU_CI_RERUN_API_SERVER"] = args.api_server
    if args.kubeconfig:
        env["KOKU_CI_RERUN_KUBECONFIG"] = args.kubeconfig

    pr_info: dict[str, Any] | None = None
    pipelinerun = args.pipelinerun
    if args.pr:
        pr_info, pipelinerun = resolve_pr_to_pipelinerun(
            args.pr,
            args.repo,
            args.check_name,
            args.scenario,
        )

    snapshot = args.snapshot
    source = "provided argument"
    if not snapshot:
        if not pipelinerun:
            raise UserError("Internal error: no PipelineRun or Snapshot target was resolved")
        snapshot, source = resolve_pipelinerun_to_snapshot(
            pipelinerun,
            args.namespace,
            args.kubearchive,
            env,
        )

    print("Resolved Konflux integration-test rerun target:")
    if pr_info:
        print(f"  PR: {pr_info['repo']}#{pr_info['number']} ({pr_info.get('url')})")
        print(f"  Failed check: {pr_info['check'].get('name')} ({pr_info['check'].get('conclusion')})")
    if pipelinerun:
        print(f"  PipelineRun: {pipelinerun}")
    print(f"  Snapshot: {snapshot} ({source})")
    print(f"  Namespace: {args.namespace}")
    print(f"  Scenario to retrigger: {args.scenario}")

    if not args.yes:
        print("\nDry run only. Re-run with --yes to apply:")
        print(
            f"  oc label snapshot {snapshot} test.appstudio.openshift.io/run={args.scenario} "
            f"-n {args.namespace} --overwrite"
        )
        return 0

    label_snapshot(snapshot, args.scenario, args.namespace, env)
    print("\nApplied Snapshot label. Matching PipelineRuns:")
    runs = list_matching_runs(snapshot, args.scenario, args.namespace, env)
    print(runs or "  No matching PipelineRuns are visible yet; check the Konflux UI or retry shortly.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except UserError as error:
        print(error, file=sys.stderr)
        raise SystemExit(2)
