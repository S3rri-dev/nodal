#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
cd "${0:A:h}/.."
python3 scripts/prepare_seed.py
python3 scripts/prepare_fixtures.py
mkdir -p build/module-cache
xcrun swiftc -swift-version 5 -Onone -module-cache-path build/module-cache -I Sources/CSQLite Sources/Support.swift Sources/Calendar.swift Sources/Store.swift Sources/Timer.swift Sources/Import.swift Sources/Planning.swift Sources/Replanning.swift Sources/Preparation.swift Sources/Grades.swift tests/features.swift tests/grade-storage.swift tests/first-run.swift tests/main.swift -o build/verification
NODAL_TEST_RESOURCES="$PWD/build/test-resources" ./build/verification
