#!/bin/sh
# Xcode Cloud: lint gate before the build. SwiftLint errors fail the build,
# warnings are only reported (see .swiftlint.yml).
set -e
brew install swiftlint >/dev/null 2>&1 || true
cd "$CI_PRIMARY_REPOSITORY_PATH"
swiftlint version
swiftlint lint --config .swiftlint.yml --reporter xcode
