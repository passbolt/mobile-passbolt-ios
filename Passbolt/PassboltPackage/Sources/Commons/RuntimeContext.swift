import class Foundation.Bundle

// https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionCreation.html
public func isInExtensionContext() -> Bool {
  Bundle.main.bundleURL.pathExtension == "appex"
}
