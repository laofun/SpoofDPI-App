# SpoofDPI App — build, sign and package
#
#   make                 build + sign + zip (default)
#   make sign SIGN_IDENTITY="My Cert"   re-sign with a self-signed identity
#   make update-core CORE_VERSION=1.5.4 refresh the embedded SpoofDPI binaries

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := all

PROJECT       := SpoofDPI App.xcodeproj
SCHEME        := SpoofDPI App
CONFIGURATION ?= Release
APP_NAME      := SpoofDPI App
BUILD_DIR     := build
DIST_DIR      := dist
APP_BUILT     := $(BUILD_DIR)/Build/Products/$(CONFIGURATION)/$(APP_NAME).app
APP_DIST      := $(DIST_DIR)/$(APP_NAME).app
ZIP           := $(DIST_DIR)/SpoofDPI.App.zip
ENTITLEMENTS  := SpoofDPI App/SpoofDPI.entitlements
BIN_DIR       := SpoofDPI App/Other/Binaries
CONSTANTS     := SpoofDPI App/Constants.swift

# "-" = ad-hoc. Set to a Keychain identity name for a self-signed certificate.
SIGN_IDENTITY ?= -
SIGN_FLAGS    ?=
CORE_REPO     := xvzc/SpoofDPI
CORE_VERSION  ?= $(shell gh release view -R $(CORE_REPO) --json tagName -q .tagName | sed 's/^v//')

.PHONY: all help build dist sign verify zip run update-core core-version clean

all: zip ## Build, sign and zip the app

help: ## Show this help
	@grep -E '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | awk -F':.*?## ' '{printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

build: ## Build the app (Apple Silicon, unsigned) with xcodebuild
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration $(CONFIGURATION) \
		-derivedDataPath $(BUILD_DIR) -destination 'generic/platform=macOS' \
		ARCHS=arm64 CODE_SIGNING_ALLOWED=NO \
		-quiet build

dist: build ## Copy the built app into dist/
	rm -rf "$(APP_DIST)" && mkdir -p $(DIST_DIR)
	ditto "$(APP_BUILT)" "$(APP_DIST)"

sign: dist ## Re-sign the app in dist/ (ad-hoc or SIGN_IDENTITY)
	@echo "Signing with identity: $(SIGN_IDENTITY)"
	# Inside-out: embedded binaries and frameworks first, then the bundle
	find "$(APP_DIST)/Contents" -type f -perm +111 ! -path '*/MacOS/*' -print0 \
		| xargs -0 -I{} codesign --force --timestamp=none $(SIGN_FLAGS) --sign "$(SIGN_IDENTITY)" "{}"
	find "$(APP_DIST)/Contents" -depth -name '*.framework' -print0 \
		| xargs -0 -I{} codesign --force --timestamp=none $(SIGN_FLAGS) --sign "$(SIGN_IDENTITY)" "{}"
	codesign --force --timestamp=none $(SIGN_FLAGS) --entitlements "$(ENTITLEMENTS)" \
		--sign "$(SIGN_IDENTITY)" "$(APP_DIST)"
	xattr -cr "$(APP_DIST)"
	@$(MAKE) --no-print-directory verify

verify: ## Verify the signature of the app in dist/
	codesign --verify --deep --strict --verbose=2 "$(APP_DIST)"
	@codesign -dv "$(APP_DIST)" 2>&1 | grep -E '^(Identifier|Signature|Authority|TeamIdentifier)'

zip: sign ## Package dist/ app as SpoofDPI.App.zip
	rm -f "$(ZIP)"
	ditto -c -k --keepParent "$(APP_DIST)" "$(ZIP)"
	@echo "Created $(ZIP)" && shasum -a 256 "$(ZIP)"

run: sign ## Launch the signed app from dist/
	open "$(APP_DIST)"

update-core: ## Download SpoofDPI CORE_VERSION (default: latest) into the app
	@test -n "$(CORE_VERSION)" || { echo "Cannot resolve CORE_VERSION"; exit 1; }
	@echo "Updating SpoofDPI core to $(CORE_VERSION)"
	tmp=$$(mktemp -d); trap 'rm -rf "$$tmp"' EXIT; \
	gh release download v$(CORE_VERSION) -R $(CORE_REPO) -D "$$tmp" \
		-p 'spoofdpi_$(CORE_VERSION)_darwin_arm64.tar.gz' -p checksums.txt; \
	(cd "$$tmp" && shasum -a 256 -c checksums.txt --ignore-missing); \
	tar -xzf "$$tmp/spoofdpi_$(CORE_VERSION)_darwin_arm64.tar.gz" -C "$$tmp"; \
	install -m 755 "$$tmp/spoofdpi" "$(BIN_DIR)/spoofdpi-arm"
	sed -i '' 's/libraryVersion = ".*"/libraryVersion = "$(CORE_VERSION)"/' "$(CONSTANTS)"
	@$(MAKE) --no-print-directory core-version

core-version: ## Print the embedded SpoofDPI version
	@"$(BIN_DIR)/spoofdpi-arm" --version | head -1
	@grep libraryVersion "$(CONSTANTS)"

clean: ## Remove build/ and dist/
	rm -rf $(BUILD_DIR) $(DIST_DIR)
