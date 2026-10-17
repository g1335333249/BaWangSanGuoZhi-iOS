#!/usr/bin/env python3
"""Validate a real iphoneos app and package its Payload as an unsigned IPA."""
import argparse
import hashlib
import json
import plistlib
import subprocess
import zipfile
from pathlib import Path

EXPECTED_ROM = "e70f0a92c205ea432080cc48c18d1d43b7fc4d45464ed7fb218b119096e7cdd9"
IPA_NAME = "BawangSanguozhi-0.1.7-build15-unsigned.ipa"


def command(*argv: str) -> str:
    return subprocess.check_output(argv, text=True).strip()


def verify_app(app: Path) -> dict:
    assert app.is_dir() and app.name == "BawangSanguozhi.app", "missing built .app"
    info = plistlib.loads((app / "Info.plist").read_bytes())
    assert info["CFBundleIdentifier"] == "com.g1335333249.BawangSanguozhi"
    assert info["CFBundleShortVersionString"] == "0.1.7"
    assert info["CFBundleVersion"] == "15"
    executable = app / info["CFBundleExecutable"]
    assert executable.is_file()
    assert command("xcrun", "lipo", "-archs", str(executable)).split() == ["arm64"]
    build = command("xcrun", "vtool", "-show-build", str(executable))
    assert "platform IOS" in build and "IOSSIMULATOR" not in build, build
    symbols = command("xcrun", "nm", "-arch", "arm64", str(executable))
    assert "_bawang_core_frame" in symbols and "_bawang_core_start_file" in symbols
    rom = app / "bawang_sanguozhi.bin"
    assert rom.is_file() and rom.stat().st_size == 0x100000
    assert hashlib.sha256(rom.read_bytes()).hexdigest() == EXPECTED_ROM
    assert sorted(app.rglob("*.bin")) == [rom], "unexpected binary game resource"
    assert not (app / "_CodeSignature").exists() and not (app / "embedded.mobileprovision").exists()
    disallowed = (".srm", ".smd", ".log", ".dump", ".dmp", "bawang_part")
    assert not any(part.name.lower().endswith(disallowed) for part in app.rglob("*"))
    return {"bundle_id": info["CFBundleIdentifier"], "version": "0.1.7",
            "build": "15", "platform": "iphoneos arm64", "rom_sha256": EXPECTED_ROM}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--commit", default=command("git", "rev-parse", "HEAD"))
    args = parser.parse_args()
    summary = verify_app(args.app)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    ipa = args.output_dir / IPA_NAME
    with zipfile.ZipFile(ipa, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in sorted(args.app.rglob("*")):
            if path.is_file():
                archive.write(path, Path("Payload") / args.app.name / path.relative_to(args.app))
    with zipfile.ZipFile(ipa) as archive:
        assert archive.testzip() is None
        names = archive.namelist()
        prefix = "Payload/BawangSanguozhi.app/"
        assert prefix + "BawangSanguozhi" in names
        assert prefix + "Info.plist" in names
        assert prefix + "bawang_sanguozhi.bin" in names
        assert hashlib.sha256(archive.read(prefix + "bawang_sanguozhi.bin")).hexdigest() == EXPECTED_ROM
    summary.update({"commit": args.commit, "ipa_name": ipa.name,
                    "ipa_bytes": ipa.stat().st_size,
                    "ipa_sha256": hashlib.sha256(ipa.read_bytes()).hexdigest()})
    (args.output_dir / "build-summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
