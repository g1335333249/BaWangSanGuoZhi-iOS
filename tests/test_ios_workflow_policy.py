#!/usr/bin/env python3
"""Prevent an accidental public or automatic ROM-bearing Actions build."""
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
text = (root / ".github/workflows/build-unsigned-ipa.yml").read_text()
trigger = re.search(r"(?ms)^on:\s*\n(.*?)(?=^[^ #\s][^\n]*:|\Z)", text)
assert trigger, "workflow trigger missing"
events = re.findall(r"^  ([a-z_]+):", trigger.group(1), flags=re.M)
assert events == ["workflow_dispatch"], events
assert "runs-on: macos-26" in text
assert text.index("Require a private repository") < text.index("Download privately held ROM")
assert 'REPO_PRIVATE: ${{ github.event.repository.private }}' in text
assert 'if: ${{ github.event.repository.private }}' in text
assert "retention-days: 7" in text
print("PASS manual-only workflow, private repository gate before ROM download and upload")
