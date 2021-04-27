import Commons

public struct KeychainItem<Value> {
  
  public var identifier: KeychainItemIdentifier
  
  public init(identifier: KeychainItemIdentifier) {
    self.identifier = identifier
  }
}
