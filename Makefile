# SpoofDPI App — build, sign, package and install (Apple Silicon only)
#
#   make                 build + sign + zip (default)
#   make install         build, sign and (re)install into /Applications
#   make bump            increment the build number before a release
#   make update-core CORE_VERSION=1.5.4 refresh the embedded SpoofDPI binary

# macOS ships GNU Make 3.81 (no .SHELLFLAGS): multi-command recipes start with $(STRICT)
SHELL  := /bin/bash
STRICT := set -euo pipefail;
.DEFAULT_GOAL := all

PROJECT       := SpoofDPI App.xcodeproj
PBXPROJ       := $(PROJECT)/project.pbxproj
SCHEME        := SpoofDPI App
CONFIGURATION ?= Release
APP_NAME      := SpoofDPI App
BUNDLE_ID     := SpoofDPI.App
BUILD_DIR     := build
DIST_DIR      := dist
APP_BUILT     := $(BUILD_DIR)/Build/Products/$(CONFIGURATION)/$(APP_NAME).app
APP_DIST      := $(DIST_DIR)/$(APP_NAME).app
APP_INSTALLED := /Applications/$(APP_NAME).app
ZIP           := $(DIST_DIR)/SpoofDPI.App.zip
ENTITLEMENTS  := SpoofDPI App/SpoofDPI.entitlements
BIN_DIR       := SpoofDPI App/Other/Binaries
CONSTANTS     := SpoofDPI App/Constants.swift
BUILD_NUMBER  := Other/ActualBuildNumber.txt

# Self-signed Keychain identity if present, otherwise ad-hoc ("-")
SIGN_CERT     := SpoofDPI Local
SIGN_IDENTITY ?= $(shell security find-identity -p codesigning | grep -q '"$(SIGN_CERT)"' && echo "$(SIGN_CERT)" || echo -)
SIGN_FLAGS    ?=
CORE_REPO     := xvzc/SpoofDPI
CORE_VERSION  ?= $(shell gh release view -R $(CORE_REPO) --json tagName -q .tagName | sed 's/^v//')

.PHONY: all help build dist sign verify zip run install uninstall bump version update-core proxy-reset clean

all: zip ## Build, sign and zip the app

help: ## Show this help
	@grep -E '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | awk -F':.*?## ' '{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

build: ## Build the app (Apple Silicon, unsigned) with xcodebuild
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration $(CONFIGURATION) \
		-derivedDataPath $(BUILD_DIR) -destination 'generic/platform=macOS' \
		ARCHS=arm64 CODE_SIGNING_ALLOWED=NO \
		-quiet build

dist: build ## Copy the built app into dist/
	rm -rf "$(APP_DIST)" && mkdir -p $(DIST_DIR)
	ditto "$(APP_BUILT)" "$(APP_DIST)"

sign: dist ## Re-sign the app in dist/ (SIGN_IDENTITY, "-" = ad-hoc)
	@echo "Signing with identity: $(SIGN_IDENTITY)"
	# Inside-out: embedded binaries and frameworks first, then the bundle
	$(STRICT) find "$(APP_DIST)/Contents" -type f -perm +111 ! -path '*/MacOS/*' -print0 \
		| xargs -0 -I{} codesign --force --timestamp=none $(SIGN_FLAGS) --sign "$(SIGN_IDENTITY)" "{}"
	$(STRICT) find "$(APP_DIST)/Contents" -depth -name '*.framework' -print0 \
		| xargs -0 -I{} codesign --force --timestamp=none $(SIGN_FLAGS) --sign "$(SIGN_IDENTITY)" "{}"
	codesign --force --timestamp=none $(SIGN_FLAGS) --entitlements "$(ENTITLEMENTS)" \
		--sign "$(SIGN_IDENTITY)" "$(APP_DIST)"
	xattr -cr "$(APP_DIST)"
	@$(MAKE) --no-print-directory verify

verify: ## Verify the signature of the app in dist/
	codesign --verify --deep --strict --verbose=2 "$(APP_DIST)"
	@codesign -dvv "$(APP_DIST)" 2>&1 | grep -E '^(Identifier|Signature|Authority)=' || true

zip: sign ## Package dist/ app as SpoofDPI.App.zip
	rm -f "$(ZIP)"
	ditto -c -k --keepParent "$(APP_DIST)" "$(ZIP)"
	@echo "Created $(ZIP)" && shasum -a 256 "$(ZIP)"

run: sign ## Launch the signed app from dist/
	open "$(APP_DIST)"

install: sign ## Quit the running app, install into /Applications and relaunch
	@$(STRICT) if pgrep -xq "$(APP_NAME)"; then \
		echo "Quitting running app"; \
		osascript -e 'tell application id "$(BUNDLE_ID)" to quit'; \
		for _ in {1..20}; do pgrep -xq "$(APP_NAME)" || break; sleep 0.5; done; \
	fi
	rm -rf "$(APP_INSTALLED)"
	ditto "$(APP_DIST)" "$(APP_INSTALLED)"
	open "$(APP_INSTALLED)"
	@echo "Installed $(APP_INSTALLED)"

uninstall: ## Quit the app and remove it from /Applications
	@if pgrep -xq "$(APP_NAME)"; then osascript -e 'tell application id "$(BUNDLE_ID)" to quit'; fi
	rm -rf "$(APP_INSTALLED)"

bump: ## Increment the build number (project + ActualBuildNumber.txt)
	$(STRICT) n=$$(( $$(cat "$(BUILD_NUMBER)") + 1 )); \
	sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = $$n;/" "$(PBXPROJ)"; \
	printf '%s' "$$n" > "$(BUILD_NUMBER)"
	@$(MAKE) --no-print-directory version

version: ## Print app version, build number and embedded SpoofDPI version
	@echo "App:      $$(grep -m1 -o 'MARKETING_VERSION = [^;]*' "$(PBXPROJ)" | cut -d' ' -f3) (build $$(cat "$(BUILD_NUMBER)"))"
	@echo "SpoofDPI: $$("$(BIN_DIR)/spoofdpi-arm" --version | head -1 | cut -d' ' -f2) (Constants: $$(grep -o 'libraryVersion = "[^"]*"' "$(CONSTANTS)" | cut -d'"' -f2))"

update-core: ## Download SpoofDPI CORE_VERSION (default: latest) into the app
	@test -n "$(CORE_VERSION)" || { echo "Cannot resolve CORE_VERSION"; exit 1; }
	@echo "Updating SpoofDPI core to $(CORE_VERSION)"
	$(STRICT) tmp=$$(mktemp -d); trap 'rm -rf "$$tmp"' EXIT; \
	gh release download v$(CORE_VERSION) -R $(CORE_REPO) -D "$$tmp" \
		-p 'spoofdpi_$(CORE_VERSION)_darwin_arm64.tar.gz' -p checksums.txt; \
	(cd "$$tmp" && shasum -a 256 -c checksums.txt --ignore-missing); \
	tar -xzf "$$tmp/spoofdpi_$(CORE_VERSION)_darwin_arm64.tar.gz" -C "$$tmp"; \
	install -m 755 "$$tmp/spoofdpi" "$(BIN_DIR)/spoofdpi-arm"
	sed -i '' 's/libraryVersion = ".*"/libraryVersion = "$(CORE_VERSION)"/' "$(CONSTANTS)"
	@$(MAKE) --no-print-directory version

proxy-reset: ## Turn off the system proxy SpoofDPI set (if the app crashed)
	$(STRICT) networksetup -listallnetworkservices | tail -n +2 | sed 's/^\*//' | while IFS= read -r svc; do \
		networksetup -setautoproxystate "$$svc" off; \
		networksetup -setproxyautodiscovery "$$svc" off; \
	done
	@echo "System proxy disabled on all network services"

clean: ## Remove build/ and dist/
	rm -rf $(BUILD_DIR) $(DIST_DIR)
