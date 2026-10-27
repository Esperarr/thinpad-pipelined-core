#!/usr/bin/env python3
"""Validate the public tree and Vivado source references."""

from __future__ import annotations

import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "thinpad_top.xpr"
SOURCE_DIR = ROOT / "thinpad_top.srcs"

TEXT_SUFFIXES = {
    ".md",
    ".py",
    ".sv",
    ".svh",
    ".tcl",
    ".v",
    ".xdc",
    ".xpr",
    ".yml",
    ".yaml",
}

FORBIDDEN_PATTERNS = {
    "absolute Windows user path": re.compile(
        r"[A-Za-z]:[\\/]+Users[\\/]", re.IGNORECASE
    ),
    "private IPv4 address": re.compile(
        r"\b(?:10\.\d{1,3}\.\d{1,3}\.\d{1,3}|"
        r"192\.168\.\d{1,3}\.\d{1,3}|"
        r"172\.(?:1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3})\b"
    ),
}


def check_project_references() -> list[str]:
    errors: list[str] = []
    tree = ET.parse(PROJECT)

    project_node = tree.getroot()
    project_path = project_node.attrib.get("Path", "")
    if re.match(r"^[A-Za-z]:[\\/]", project_path):
        errors.append(f"Vivado project contains an absolute path: {project_path}")

    for file_node in tree.iter("File"):
        raw_path = file_node.attrib.get("Path")
        if not raw_path:
            continue
        resolved = raw_path.replace("$PSRCDIR", str(SOURCE_DIR))
        resolved = resolved.replace("$PPRDIR", str(ROOT))
        path = Path(resolved)
        if not path.is_file():
            errors.append(f"Missing referenced file: {raw_path}")

    return errors


def check_text_patterns() -> list[str]:
    errors: list[str] = []
    for path in ROOT.rglob("*"):
        if not path.is_file() or ".git" in path.parts:
            continue
        if path.resolve() == Path(__file__).resolve():
            continue
        if path.suffix.lower() not in TEXT_SUFFIXES:
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for label, pattern in FORBIDDEN_PATTERNS.items():
            match = pattern.search(text)
            if match:
                relative = path.relative_to(ROOT)
                errors.append(f"{relative}: found {label}: {match.group(0)!r}")
    return errors


def main() -> int:
    errors = check_project_references() + check_text_patterns()
    if errors:
        print("Public-repository audit failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1

    print("Public-repository audit passed.")
    print(f"  - Vivado project references resolve under {ROOT}")
    print("  - No configured identifying-data patterns were found")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
