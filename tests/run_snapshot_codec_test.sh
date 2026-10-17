#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# The persistence codec is Foundation-only. Exclude the UIKit preview helper
# from Linux portability testing; iOS compile checks it separately.
python3 - "$root" "$tmp" <<'PY'
import pathlib,sys
src=pathlib.Path(sys.argv[1]+'/apps/ios/BawangSanguozhi/App/ReplaySnapshotStore.swift').read_text()
src=src.replace('import UIKit\n','')
a=src.index('    static func thumbnail(_ id: UUID) -> UIImage? {')
b=src.index('    static func delete(_ id: UUID) {', a)
src=src[:a]+src[b:]
pathlib.Path(sys.argv[2]+'/codec.swift').write_text(src)
pathlib.Path(sys.argv[2]+'/save.swift').write_text('''import Foundation\nenum SaveManager { static var support = FileManager.default.temporaryDirectory }\n''')
PY
swiftc "$tmp/codec.swift" "$tmp/save.swift" "$root/tests/test_snapshot_codec.swift" -o "$tmp/test"
"$tmp/test"
