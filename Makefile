# Wochi — Xcode project generator
# Requires: brew install xcodegen  (run once on your Mac)

.PHONY: generate open clean

generate:
	xcodegen generate

open: generate
	open Wochi.xcodeproj

clean:
	rm -rf Wochi.xcodeproj
