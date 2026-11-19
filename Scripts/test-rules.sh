#!/usr/bin/env bash
set -euo pipefail
RULES_DIR=$(mktemp -d)
mkdir -p "$RULES_DIR/Sources/Qiling" "$RULES_DIR/Tests/QilingTests"
cp Sources/Growth.swift Sources/HealthyRules.swift Sources/CampusRules.swift "$RULES_DIR/Sources/Qiling/"
cp Tests/GrowthTests.swift Tests/CampusAndHealthTests.swift "$RULES_DIR/Tests/QilingTests/"
cat > "$RULES_DIR/Package.swift" <<'SWIFT'
// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "QilingRules", targets: [
    .target(name: "Qiling"),
    .testTarget(name: "QilingTests", dependencies: ["Qiling"])
])
SWIFT
swift test --package-path "$RULES_DIR"
