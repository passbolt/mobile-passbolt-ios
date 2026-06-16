SHELL := bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:

PROJECT_PATH=Passbolt/Passbolt.xcodeproj
DERIVED_DATA=Passbolt/DerivedData
ARCHIVE_PATH=Passbolt.xcarchive
IPA_PATH=Passbolt.ipa
EXPORT_OPTIONS=Tools/export-options.plist

TEST_PLATFORM = iOS Simulator,name=iPhone 15

E2E_DEVICE = iPhone 17 Pro
E2E_SIM_1 = iPhone 17 Pro
E2E_SIM_2 = iPhone Air
E2E_SIM_3 = iPhone SE
E2E_PARALLEL = true

.PHONY: clean clean_build test ui_test e2e_test e2e_test_multi archive build_publish lint format licenses_plist

clean:
	rm -rf *.ipa
	rm -rf *.xcarchive
	rm -rf TestResults.xcresult
	rm -rf TestResults-*.xcresult
	rm -rf lint-report
	rm -rf test-coverage-report.txt
	rm -rf $(DERIVED_DATA)
	rm -rf ~/tmp/passbolt
	xcodebuild -project $(PROJECT_PATH) clean

clean_build:
	rm -rf TestResults.xcresult
	rm -rf TestResults-*.xcresult
	rm -rf $(DERIVED_DATA)
	xcodebuild -project $(PROJECT_PATH) clean

test:
	xcodebuild -project $(PROJECT_PATH) -scheme Passbolt -destination platform="$(TEST_PLATFORM)" -resultBundlePath TestResults.xcresult -derivedDataPath $(DERIVED_DATA) test -enableCodeCoverage YES || exit -1
	xcrun xccov view --report TestResults.xcresult --only-targets > test-coverage-report.txt

ui_test: clean_build
	defaults write com.apple.iphonesimulator ConnectHardwareKeyboard 0
	xcodebuild -project $(PROJECT_PATH) -scheme PassboltUITests -destination platform="$(TEST_PLATFORM)" -resultBundlePath TestResults.xcresult -derivedDataPath $(DERIVED_DATA) test || exit -1

e2e_test: clean_build
	defaults write com.apple.iphonesimulator ConnectHardwareKeyboard 0
	SIM_UDID="" ; \
	DEVICE="$(E2E_DEVICE)" ; \
	case "$$DEVICE" in "iPhone SE") DEVICE="iPhone SE (3rd generation)" ;; esac ; \
	trap '[ -n "$$SIM_UDID" ] && xcrun simctl delete "$$SIM_UDID" 2>/dev/null || true' EXIT ; \
	SIM_UDID=$$(xcrun simctl create "E2E-$$DEVICE" "$$DEVICE") && \
	xcrun simctl boot "$$SIM_UDID" && \
	xcrun simctl spawn "$$SIM_UDID" defaults write "Apple Global Domain" AppleLanguages -array en && \
	xcrun simctl spawn "$$SIM_UDID" defaults write "Apple Global Domain" AppleLocale -string en_US && \
	xcrun simctl shutdown "$$SIM_UDID" && \
	xcodebuild -project $(PROJECT_PATH) -scheme PassboltE2ETests \
		-destination "platform=iOS Simulator,id=$$SIM_UDID" \
		-resultBundlePath TestResults.xcresult \
		-derivedDataPath $(DERIVED_DATA) test

e2e_test_multi: clean_build
	defaults write com.apple.iphonesimulator ConnectHardwareKeyboard 0
	resolve() { case "$$1" in "iPhone SE") echo "iPhone SE (3rd generation)" ;; *) echo "$$1" ;; esac ; } ; \
	force_en() { xcrun simctl boot "$$1" && xcrun simctl spawn "$$1" defaults write "Apple Global Domain" AppleLanguages -array en && xcrun simctl spawn "$$1" defaults write "Apple Global Domain" AppleLocale -string en_US && xcrun simctl shutdown "$$1" ; } ; \
	D1=$$(resolve "$(E2E_SIM_1)") ; \
	D2=$$(resolve "$(E2E_SIM_2)") ; \
	D3=$$(resolve "$(E2E_SIM_3)") ; \
	SIM1="" ; SIM2="" ; SIM3="" ; \
	trap 'for s in "$$SIM1" "$$SIM2" "$$SIM3"; do [ -n "$$s" ] && xcrun simctl delete "$$s" 2>/dev/null || true; done' EXIT ; \
	SIM1=$$(xcrun simctl create "E2E-$$D1" "$$D1") && force_en "$$SIM1" && \
	SIM2=$$(xcrun simctl create "E2E-$$D2" "$$D2") && force_en "$$SIM2" && \
	SIM3=$$(xcrun simctl create "E2E-$$D3" "$$D3") && force_en "$$SIM3" && \
	if [ "$(E2E_PARALLEL)" = "true" ]; then \
		xcodebuild -project $(PROJECT_PATH) \
			-scheme PassboltE2ETests \
			-destination "platform=iOS Simulator,id=$$SIM1" \
			-destination "platform=iOS Simulator,id=$$SIM2" \
			-destination "platform=iOS Simulator,id=$$SIM3" \
			-resultBundlePath TestResults.xcresult \
			-derivedDataPath $(DERIVED_DATA) \
			test ; \
	else \
		declare -a NAMES=("$$D1" "$$D2" "$$D3") ; \
		declare -a UUIDS=("$$SIM1" "$$SIM2" "$$SIM3") ; \
		for i in $${!NAMES[@]}; do \
			echo "=== Running E2E tests on $${NAMES[$$i]} ===" ; \
			result_name=$$(echo "$${NAMES[$$i]}" | tr ' ' '-') ; \
			xcodebuild -project $(PROJECT_PATH) \
				-scheme PassboltE2ETests \
				-destination "platform=iOS Simulator,id=$${UUIDS[$$i]}" \
				-resultBundlePath "TestResults-$$result_name.xcresult" \
				-derivedDataPath $(DERIVED_DATA) \
				test || exit 1 ; \
		done ; \
	fi

archive: clean
	xcodebuild archive -project $(PROJECT_PATH) -scheme Passbolt -configuration Release -archivePath $(ARCHIVE_PATH) -derivedDataPath $(DERIVED_DATA)
	xcodebuild -exportArchive -archivePath $(ARCHIVE_PATH) -exportPath $(IPA_PATH) -exportOptionsPlist  $(EXPORT_OPTIONS)

build_publish: archive
	xcrun altool --upload-app -f $(IPA_PATH)/Passbolt.ipa -u $(ASC_USER) --apiKey $(ASC_KEY) --apiIssuer $(ASC_KEY_ISSUER) --type ios
	echo "Uploaded release build: $(BUILD)"

lint:
	swift run --configuration release --package-path Tools/formatter --scratch-path ~/tmp/passbolt -- swift-format lint --configuration ./Tools/code-format.json --parallel --recursive ./Passbolt/PassboltPackage/Package.swift ./Passbolt/PassboltPackage/Sources ./Passbolt/PassboltPackage/Tests  ./Passbolt/PassboltUITests ./Passbolt/PassboltE2ETests ./Passbolt/Passbolt 2> lint-report

format:
	swift run --configuration release --package-path Tools/formatter --scratch-path ~/tmp/passbolt -- swift-format format --configuration ./Tools/code-format.json --in-place --parallel --recursive ./Passbolt/PassboltPackage/Package.swift ./Passbolt/PassboltPackage/Sources ./Passbolt/PassboltPackage/Tests ./Passbolt/PassboltUITests ./Passbolt/PassboltE2ETests ./Passbolt/Passbolt

licenses_plist:
	swift run --package-path Tools/license --scratch-path ~/tmp/passbolt -- license-plist --suppress-opening-directory --fail-if-missing-license --package-path Passbolt/PassboltPackage/Package.swift --config-path Tools/license-plist.yml --prefix LicensePlist --output-path Passbolt/Passbolt/Settings.bundle
