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

.PHONY: clean test ui_test archive build_publish lint format licenses_plist

clean:
	rm -rf *.ipa
	rm -rf *.xcarchive
	rm -rf TestResults.xcresult
	rm -rf lint-report
	rm -rf test-coverage-report.txt
	rm -rf $(DERIVED_DATA)
	rm -rf ~/tmp/passbolt
	xcodebuild -project $(PROJECT_PATH) clean

test:
	xcodebuild -project $(PROJECT_PATH) -scheme Passbolt -destination platform="$(TEST_PLATFORM)" -resultBundlePath TestResults.xcresult -derivedDataPath $(DERIVED_DATA) test -enableCodeCoverage YES || exit -1
	xcrun xccov view --report TestResults.xcresult --only-targets > test-coverage-report.txt

ui_test: clean_build
	defaults write com.apple.iphonesimulator ConnectHardwareKeyboard 0
	xcodebuild -project $(PROJECT_PATH) -scheme PassboltUITests -destination platform="$(TEST_PLATFORM)" -resultBundlePath TestResults.xcresult -derivedDataPath $(DERIVED_DATA) test || exit -1

archive: clean
	xcodebuild archive -project $(PROJECT_PATH) -scheme Passbolt -configuration Release -archivePath $(ARCHIVE_PATH) -derivedDataPath $(DERIVED_DATA)
	xcodebuild -exportArchive -archivePath $(ARCHIVE_PATH) -exportPath $(IPA_PATH) -exportOptionsPlist  $(EXPORT_OPTIONS)

build_publish: archive
	xcrun altool --upload-app -f $(IPA_PATH)/Passbolt.ipa -u $(ASC_USER) --apiKey $(ASC_KEY) --apiIssuer $(ASC_KEY_ISSUER) --type ios
	echo "Uploaded release build: $(BUILD)"

lint:
	swift run --configuration release --package-path Tools/formatter --scratch-path ~/tmp/passbolt -- swift-format lint --configuration ./Tools/code-format.json --parallel --recursive ./Passbolt/PassboltPackage/Package.swift ./Passbolt/PassboltPackage/Sources ./Passbolt/PassboltPackage/Tests  ./Passbolt/PassboltUITests ./Passbolt/Passbolt 2> lint-report

format:
	swift run --configuration release --package-path Tools/formatter --scratch-path ~/tmp/passbolt -- swift-format format --configuration ./Tools/code-format.json --in-place --parallel --recursive ./Passbolt/PassboltPackage/Package.swift ./Passbolt/PassboltPackage/Sources ./Passbolt/PassboltPackage/Tests ./Passbolt/PassboltUITests ./Passbolt/Passbolt

licenses_plist:
	swift run --package-path Tools/license --scratch-path ~/tmp/passbolt -- license-plist --suppress-opening-directory --fail-if-missing-license --package-path Passbolt/PassboltPackage/Package.swift --config-path Tools/license-plist.yml --prefix LicensePlist --output-path Passbolt/Passbolt/Settings.bundle
