#!/usr/bin/env python3
"""Keep the checked-out ROM build manual-only and source-backed."""
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
text = (root / ".github/workflows/build-unsigned-ipa.yml").read_text()
trigger = re.search(r"(?ms)^on:\s*\n(.*?)(?=^[^ #\s][^\n]*:|\Z)", text)
assert trigger, "workflow trigger missing"
events = re.findall(r"^  ([a-z_]+):", trigger.group(1), flags=re.M)
assert events == ["workflow_dispatch"], events
assert "runs-on: macos-26" in text
assert "Verify checked-out SMD ROM" in text
assert "8128fb9828b5474b37f928aed6a771cb2e03457aeb13293d29f3cfb1c83ba6b4" in text
assert "gh release download" not in text and "GH_TOKEN" not in text
assert "REPO_PRIVATE" not in text and "rom_release_tag" not in text
assert "BawangSanguozhi-iOS-0.1.3-Build11" in text
assert "retention-days: 7" in text
print("PASS manual-only workflow with checked-out ROM and expected IPA artifact")
