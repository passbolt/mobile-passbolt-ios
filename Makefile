PROJECT_PATH='Passbolt/Passbolt.xcodeproj'
DERIVED_DATA='Passbolt/DerivedData'

clean:
	xcodebuild -project $(PROJECT_PATH) clean

lint_autocorrect:
	swiftlint --fix

remove_derived:
	rm -Rd $(DERIVED_DATA)

test:
	xcodebuild -project $(PROJECT_PATH) -scheme PassboltTests -destination 'platform=iOS Simulator,name=iPhone 12' test

