SHELL := bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:

PROJECT_PATH='Passbolt/Passbolt.xcodeproj'
DERIVED_DATA='Passbolt/DerivedData'

clean:
	xcodebuild -project $(PROJECT_PATH) clean

lint: 
	swift run --package-path Tools/lint --build-path ~/tmp/passbolt swiftlint Passbolt

lint_autocorrect:
	swift run --package-path Tools/lint --build-path ~/tmp/passbolt swiftlint --fix Passbolt

remove_derived:
	rm -Rd $(DERIVED_DATA)

test:
	rm -rf TestResults.xcresult
	rm -rf ./DerivedData/
	
	xcodebuild -project $(PROJECT_PATH) -scheme Passbolt -destination 'platform=iOS Simulator,name=iPhone 12' -resultBundlePath TestResults.xcresult -derivedDataPath $(DERIVED_DATA) test -enableCodeCoverage YES || exit -1
	xcrun xccov view --report TestResults.xcresult --only-targets
