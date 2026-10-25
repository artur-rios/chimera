"""Validate Chimera's Yggdrasil release and deployment contract.

The catalog is the one of the yggdrasil installation that deploys Chimera: ci/branch-policy.sh passes
"$YGGDRASIL_DIR/catalog.yaml", the pipeline's own yggdrasil checkout, so a release is checked against the
catalog it is released with. Any path works by hand.
"""

from __future__ import annotations

import pathlib
import sys
from typing import Any

import yaml


ENVIRONMENT_IDS = ["local", "development", "homologation", "production"]
# The checks Jenkins runs, named as in Chimera's yggdrasil.yml, in the catalog's order.
REQUIRED_CHECKS = [
    "analyze-and-test",
    "browser-tests",
    "native-linux",
    "container",
    "accessibility-performance",
    "cleanup-contract",
    "generated-library",
    "evaluate-projects",
    "version-contract",
    "build-contract",
    "minimal-library",
]
# The Windows and macOS jobs that stay GitHub Actions workflows, exactly as GitHub reports them.
REQUIRED_ACTIONS_CHECKS = [
    "Safari",
    "Native (windows)",
    "Artifact cleanup (windows-latest)",
    "Generated NuGet library (windows-latest)",
    ".NET project evaluation (windows-latest)",
    "Project version editing (windows-latest)",
    ".NET build, coverage and process lifecycle (windows-latest)",
    "Minimal library contracts (windows-latest)",
    "Windows owned terminal lifecycle",
]


def validate(catalog: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(catalog, dict):
        return ["catalog: expected a YAML object"]
    if catalog.get("owner") != "artur-rios":
        errors.append("owner: expected artur-rios")

    environments = catalog.get("environments")
    if not isinstance(environments, list):
        return errors + ["environments: expected a list"]
    environment_by_id = {
        value.get("id"): value
        for value in environments
        if isinstance(value, dict) and isinstance(value.get("id"), str)
    }
    actual_order = [
        value.get("id") for value in environments if isinstance(value, dict)
    ]
    if actual_order != ENVIRONMENT_IDS:
        errors.append(
            "environments: expected promotion order " + ", ".join(ENVIRONMENT_IDS)
        )

    application = _chimera_application(catalog)
    if application is None:
        return errors + ["chimera: catalog application is missing"]
    expected_fields = {
        "kind": "web",
        "health": "http://chimera:8080/healthz",
        "host": "chimera",
    }
    for field, expected in expected_fields.items():
        if application.get(field) != expected:
            errors.append(f"chimera.{field}: expected {expected}")
    if application.get("repository", "chimera") != "chimera":
        errors.append("chimera.repository: expected chimera")
    if application.get("releaseArtifacts") is not True:
        errors.append("chimera.releaseArtifacts: expected true")
    if application.get("checks") != REQUIRED_CHECKS:
        errors.append("chimera.checks: required check names or order changed")
    if application.get("actionsChecks") != REQUIRED_ACTIONS_CHECKS:
        errors.append(
            "chimera.actionsChecks: required GitHub Actions check names or order changed"
        )
    container = application.get("container")
    if not isinstance(container, dict) or container.get("service") != "web":
        errors.append("chimera.container.service: expected web")

    overrides = application.get("environments")
    if overrides is not None:
        if not isinstance(overrides, dict):
            errors.append("chimera.environments: expected an object when present")
            overrides = {}
        elif list(overrides) != ENVIRONMENT_IDS:
            errors.append(
                "chimera.environments: overrides must retain all four environments in order"
            )

    expected_triggers = {
        "local": ("manual", []),
        "development": ("branch", ["develop"]),
        "homologation": ("branch", ["release/*"]),
        "production": ("release", []),
    }
    for environment_id, (trigger, branches) in expected_triggers.items():
        environment = environment_by_id.get(environment_id)
        if environment is None:
            errors.append(f"{environment_id}: environment is missing")
            continue
        resolved = dict(environment)
        if isinstance(overrides, dict):
            override = overrides.get(environment_id)
            if isinstance(override, dict):
                resolved.update(override)
        if resolved.get("trigger", "manual") != trigger:
            errors.append(f"{environment_id}.trigger: expected {trigger}")
        actual_branches = resolved.get("branches", [])
        if isinstance(actual_branches, str):
            actual_branches = [actual_branches]
        if actual_branches != branches:
            errors.append(
                f"{environment_id}.branches: expected {', '.join(branches) or 'none'}"
            )
        if environment_id != "local" and not resolved.get("agent"):
            errors.append(f"{environment_id}.agent: deployment agent is missing")
        if environment_id == "production" and resolved.get("approval") is not True:
            errors.append("production.approval: expected true")

    return errors


def _chimera_application(catalog: dict[str, Any]) -> dict[str, Any] | None:
    systems = catalog.get("systems")
    if not isinstance(systems, list):
        return None
    for system in systems:
        if not isinstance(system, dict) or system.get("id") != "chimera":
            continue
        applications = system.get("applications")
        if not isinstance(applications, list):
            return None
        for application in applications:
            if isinstance(application, dict) and application.get("id") == "chimera":
                return application
    return None


def main(arguments: list[str]) -> int:
    if len(arguments) != 1:
        print(
            "Usage: python tool/validate_yggdrasil_contract.py <catalog.yaml>",
            file=sys.stderr,
        )
        return 64
    path = pathlib.Path(arguments[0])
    try:
        catalog = yaml.safe_load(path.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError) as error:
        print(f"catalog: {error}", file=sys.stderr)
        return 1
    errors = validate(catalog)
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print("Yggdrasil Chimera release contract: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
