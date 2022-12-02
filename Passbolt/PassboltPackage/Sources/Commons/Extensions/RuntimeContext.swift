import class Foundation.Bundle

// https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionCreation.html
public var isInApplicationContext: Bool {
  Bundle.main.bundleURL.pathExtension == "app"
}

public var isInExtensionContext: Bool {
  Bundle.main.bundleURL.pathExtension == "appex"
}
