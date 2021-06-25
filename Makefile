SHELL := bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:

PROJECT_PATH=Passbolt/Passbolt.xcodeproj
DERIVED_DATA=Passbolt/DerivedData
ARCHIVE_PATH=Passbolt.xcarchive
IPA_PATH=Passbolt.ipa
EXPORT_OPTIONS=Tools/export-options.plist
BUILD := $(shell date +%s)


clean:
	xcodebuild -project $(PROJECT_PATH) clean

lint: 
	swift run --package-path Tools/lint --build-path ~/tmp/passbolt swiftlint Passbolt --config Passbolt/.swiftlint.yml --reporter html > lint-report.html

remove_derived:
	rm -Rd $(DERIVED_DATA)

test:
	rm -rf TestResults.xcresult
	rm -rf ./DerivedData/
	
	xcodebuild -project $(PROJECT_PATH) -scheme Passbolt -destination 'platform=iOS Simulator,name=iPhone 12' -resultBundlePath TestResults.xcresult -derivedDataPath $(DERIVED_DATA) test -enableCodeCoverage YES || exit -1
	xcrun xccov view --report TestResults.xcresult --only-targets > test-coverage-report.txt

qa_build_publish: 
	rm -rf *.ipa
	rm -rf *.xcarchive
	cd Passbolt; agvtool new-version -all $(BUILD)
	xcodebuild archive -project $(PROJECT_PATH) -scheme Passbolt -configuration Release -archivePath $(ARCHIVE_PATH) -derivedDataPath $(DERIVED_DATA)
	xcodebuild -exportArchive -archivePath $(ARCHIVE_PATH) -exportPath $(IPA_PATH) -exportOptionsPlist  $(EXPORT_OPTIONS)
	xcrun altool --upload-app -f $(IPA_PATH)/Passbolt.ipa -u $(ASC_USER) --apiKey $(ASC_KEY) --apiIssuer $(ASC_KEY_ISSUER) --type ios
