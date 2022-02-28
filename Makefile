SHELL := bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:

PROJECT_PATH=Passbolt/Passbolt.xcodeproj
DERIVED_DATA=Passbolt/DerivedData
ARCHIVE_PATH=Passbolt.xcarchive
IPA_PATH=Passbolt.ipa
EXPORT_OPTIONS=Tools/export-options.plist

# use gitlab defined version for the app version
# or fallback to the latest git tag
ifdef APP_VERSION
	MARKETING_VERSION := $(APP_VERSION)
else
	MARKETING_VERSION := $(git describe --tags --abbrev=0)
endif

# use gitlab pipeline id for the app build
# or fallback to the current date 
ifdef CI_PIPELINE_IID
	BUILD_NUMBER := $(CI_PIPELINE_IID)
else
	BUILD_NUMBER := $(shell date +%s)
endif

TEST_PLATFORM = iOS Simulator,name=iPhone 13

.PHONY: clean_artifacts clean_build clean test version_setup qa_build qa_build_validation qa_build_publish lint format prepare_licenses

clean_artifacts:
	rm -rf *.ipa
	rm -rf *.xcarchive
	rm -rf TestResults.xcresult

clean_build: clean_artifacts
	rm -rf $(DERIVED_DATA)

clean: clean_build
	rm -rf ~/tmp/passbolt
	xcodebuild -project $(PROJECT_PATH) clean

test: clean_build
	xcodebuild -project $(PROJECT_PATH) -scheme Passbolt -destination platform="$(TEST_PLATFORM)" -resultBundlePath TestResults.xcresult -derivedDataPath $(DERIVED_DATA) test -enableCodeCoverage YES || exit -1
	xcrun xccov view --report TestResults.xcresult --only-targets > test-coverage-report.txt

version_setup:
	cd Passbolt; agvtool new-version -all $(BUILD_NUMBER)
	cd Passbolt; agvtool new-marketing-version $(MARKETING_VERSION)

qa_build: clean_build version_setup	
	xcodebuild archive -project $(PROJECT_PATH) -scheme Passbolt -configuration Release -archivePath $(ARCHIVE_PATH) -derivedDataPath $(DERIVED_DATA)
	xcodebuild -exportArchive -archivePath $(ARCHIVE_PATH) -exportPath $(IPA_PATH) -exportOptionsPlist  $(EXPORT_OPTIONS)

qa_build_validation: qa_build
	xcrun altool --validate-app -f $(IPA_PATH)/Passbolt.ipa -u $(ASC_USER) --apiKey $(ASC_KEY) --apiIssuer $(ASC_KEY_ISSUER) --type ios
	
qa_build_publish: qa_build
	xcrun altool --upload-app -f $(IPA_PATH)/Passbolt.ipa -u $(ASC_USER) --apiKey $(ASC_KEY) --apiIssuer $(ASC_KEY_ISSUER) --type ios
	echo "Uploaded build: $(BUILD)"

lint:
	# temporarily disable linting due to swift compiler compatibility issue
	# swift run --configuration release --package-path Tools/formatter --build-path ~/tmp/passbolt -- swift-format lint --configuration ./Tools/code-format.json --parallel --recursive ./Passbolt/PassboltPackage/Package.swift ./Passbolt/PassboltPackage/Sources ./Passbolt/PassboltPackage/Tests 2> lint-report
	echo "Linting temporarily disabled" > lint-report

format:
	swift run --configuration release --package-path Tools/formatter --build-path ~/tmp/passbolt -- swift-format format --configuration ./Tools/code-format.json --in-place --parallel --recursive ./Passbolt/PassboltPackage/Package.swift ./Passbolt/PassboltPackage/Sources ./Passbolt/PassboltPackage/Tests

prepare_licenses:
	swift run --package-path Tools/license --build-path ~/tmp/passbolt -- license-plist --suppress-opening-directory --fail-if-missing-license --package-path Passbolt/PassboltPackage/Package.swift --config-path Tools/license-plist.yml --prefix LicensePlist --output-path Passbolt/Passbolt/Settings.bundle