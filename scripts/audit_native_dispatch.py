#!/usr/bin/env python3
"""Compare offline pointer candidates with the actual generated AOT dispatcher.

This is static evidence only. It never edits game.toml and never treats a
plausible opcode in an unbounded table scan as proof of execution.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_ROM = "e70f0a92c205ea432080cc48c18d1d43b7fc4d45464ed7fb218b119096e7cdd9"
sys.path.insert(0, str(ROOT / "analysis/static_audit"))
from md68k_probe import BadInstruction, Decoder  # noqa: E402


def addresses(pattern: str, content: str) -> set[int]:
    return {int(value, 16) for value in re.findall(pattern, content)}


def generated_sites(generated: Path) -> tuple[set[int], set[int], set[int]]:
    dispatch = (generated / "bawang_dispatch.c").read_text()
    entries = addresses(r"\{ 0x([0-9A-F]{6})u, func_", dispatch)
    instructions: set[int] = set()
    labels: set[int] = set()
    for part in sorted(generated.glob("bawang_part*.c")):
        source = part.read_text()
        instructions.update(addresses(r"GEN_COSIM_INSN_PC\(0x([0-9A-F]{6})u\)", source))
        labels.update(addresses(r"label_([0-9A-F]{6}):", source))
    if not entries or not instructions or len(list(generated.glob("bawang_part*.c"))) != 32:
        raise ValueError("Expected the complete 32-part generated native output")
    return entries, instructions, labels


def inspect_entry(decoder: Decoder, rom: bytes, addr: int) -> tuple[str, str, str]:
    if addr & 1 or addr < 0x200 or addr >= len(rom):
        return "INVALID", "outside aligned executable ROM range", ""
    try:
        first = decoder.decode(addr)
        if first.mnemonic in ("ILLEGAL", "STOP"):
            return "INVALID", "non-executable first opcode", first.mnemonic
    except (BadInstruction, ValueError, IndexError) as error:
        return "INVALID", f"first opcode rejected: {error}", ""
    instruction = f"{first.mnemonic} {first.operands}".strip()
    previous = int.from_bytes(rom[addr - 2:addr], "big")
    if previous == 0x4E75:  # RTS is a strong independent-function boundary.
        return "MISSING_VALID", "pointer table plus independent entry after RTS", instruction
    try:
        before = decoder.decode(addr - 4)
        if before.length == 4 and before.mnemonic == "BRA":
            return "MISSING_VALID", "pointer table plus entry after unconditional BRA", instruction
    except (BadInstruction, ValueError, IndexError):
        pass
    return "AMBIGUOUS", "no independently verified entry boundary", instruction


def audit(rom: bytes, rows: list[dict], generated: Path) -> list[dict]:
    entries, instructions, labels = generated_sites(generated)
    decoder = Decoder(rom)
    sources: dict[int, list[dict]] = defaultdict(list)
    for row in rows:
        sources[int(row["candidate_target"], 16)].append(row)
    results = []
    for addr, references in sorted(sources.items()):
        status, reason, opcode = inspect_entry(decoder, rom, addr)
        slots_ok = all(
            int.from_bytes(rom[int(r["slot_address"], 16):int(r["slot_address"], 16) + 4], "big") == addr
            for r in references
        )
        if not slots_ok:
            status, reason = "AMBIGUOUS", "pointer slot does not match this ROM"
        elif addr in entries:
            status, reason = "COVERED", "exact native dispatch entry"
        elif addr in instructions or addr in labels:
            status, reason = "INTERIOR_ENTRY", "generated instruction/label lacks exact dispatch; review entry mapping"
        results.append({
            "address": f"0x{addr:06X}",
            "status": status,
            "reason": reason,
            "source_tables": sorted({r["table_base"] for r in references}),
            "call_sites": sorted({r["call_site"] for r in references}),
            "pointer_slots": sorted({r["slot_address"] for r in references}),
            "rom_bytes": rom[addr:addr + 12].hex() if addr < len(rom) else "",
            "first_instruction": opcode,
            "in_native_dispatch": addr in entries,
            "in_generated_instructions": addr in instructions,
            "in_generated_labels": addr in labels,
            "action": "already covered" if status == "COVERED" else
                      "add verified AOT entry" if status == "MISSING_VALID" else
                      "repair interior dispatch" if status == "INTERIOR_ENTRY" else
                      "do not add without further evidence",
        })
    return results


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rom", type=Path, default=ROOT / "input/bawang_sanguozhi.bin")
    parser.add_argument("--candidates", type=Path, default=ROOT / "analysis/static_audit/bawang_indirect_pointer_targets.csv")
    parser.add_argument("--generated", type=Path, default=ROOT / "games/bawang_sanguozhi/build/generated")
    parser.add_argument("--output", type=Path, default=ROOT / "analysis/native_dispatch_audit")
    args = parser.parse_args()
    rom = args.rom.read_bytes()
    digest = hashlib.sha256(rom).hexdigest()
    if digest != EXPECTED_ROM:
        raise SystemExit(f"ROM SHA256 mismatch: {digest}")
    with args.candidates.open(newline="", encoding="utf-8") as file:
        candidates = list(csv.DictReader(file))
    results = audit(rom, candidates, args.generated)
    counts = dict(sorted(Counter(row["status"] for row in results).items()))
    summary = {"rom_sha256": digest, "pointer_records": len(candidates),
               "unique_targets": len(results), "counts": counts, "targets": results,
               "unresolved_call_site": "0x035DF8: A4 = 0x007760 or 0x007B76 in func_035D62; both exact native dispatch entries"}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.with_suffix(".json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    with args.output.with_suffix(".csv").open("w", newline="", encoding="utf-8") as file:
        fields = ["address", "status", "reason", "source_tables", "call_sites", "pointer_slots",
                  "rom_bytes", "first_instruction", "in_native_dispatch", "in_generated_instructions",
                  "in_generated_labels", "action"]
        writer = csv.DictWriter(file, fieldnames=fields)
        writer.writeheader()
        for result in results:
            writer.writerow({key: ";".join(value) if isinstance(value, list) else value
                             for key, value in result.items()})
    lines = ["# Native dispatch audit", "", f"ROM SHA256: `{digest}`", "",
             f"Pointer records: {len(candidates)}; unique targets: {len(results)}", "",
             "| Classification | Count |", "|---|---:|"]
    lines.extend(f"| {key} | {count} |" for key, count in counts.items())
    lines.extend(["", "Static candidates are not execution coverage. MISSING_VALID uses a verified ROM pointer"
                  " plus a boundary immediately after RTS or unconditional BRA. No game.toml edit is automatic.", "",
                  "A4 at `$035DF8` is assigned `$007760` or `$007B76` in generated `$035D62`; both are dispatched.", "",
                  "## Unresolved candidates", ""])
    lines.extend(f"- {row['address']}: {row['status']} — {row['reason']} ({row['first_instruction']})"
                 for row in results if row["status"] not in ("COVERED", "MISSING_VALID"))
    args.output.with_suffix(".md").write_text("\n".join(lines) + "\n")
    print(json.dumps({key: summary[key] for key in ("pointer_records", "unique_targets", "counts")}, ensure_ascii=False))


if __name__ == "__main__":
    main()
