#!/usr/bin/env python3
"""Locate the first instruction/state difference in two opt-in Co-Sim logs."""
import argparse
import re
from pathlib import Path

PATTERN = re.compile(r"^\[INSN\] #(\d+) frame=(\d+) pc=([0-9A-F]+) "
                     r"cyc=(\d+) (.*)$")


def records(path):
    for line in Path(path).read_text().splitlines():
        match = PATTERN.match(line)
        if match:
            number, frame, pc, cycle, state = match.groups()
            yield int(number), int(frame), pc, int(cycle), state


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("native_log")
    parser.add_argument("interpreter_log")
    args = parser.parse_args()
    a, b = list(records(args.native_log)), list(records(args.interpreter_log))
    if not a or not b:
        parser.error("both logs must contain [INSN] records")
    cycle_offsets = set()
    for left, right in zip(a, b):
        if left[:3] + left[4:] != right[:3] + right[4:]:
            print(f"First instruction/state difference at record {left[0]}")
            print(f"native:      {left}")
            print(f"interpreter: {right}")
            print(f"Earlier cycle offsets (native minus interpreter): "
                  f"{sorted(cycle_offsets)}")
            return 1
        cycle_offsets.add(left[3] - right[3])
    print(f"First {min(len(a), len(b))} instruction states match; "
          f"cycle offsets: {sorted(cycle_offsets)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
