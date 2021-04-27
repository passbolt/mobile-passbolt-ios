import Commons

public struct KeychainItemIdentifier {
  
  public typealias Key = Tagged<String, Self>
  public typealias Tag = Tagged<String, Self>
  
  public var key: Key
  public var tag: Tag?
  public var requiresBiometrics: Bool
  
  public init(
    key: Key,
    tag: Tag?,
    requiresBiometrics: Bool
  ) {
    self.key = key
    self.tag = tag
    self.requiresBiometrics = requiresBiometrics
  }
}
