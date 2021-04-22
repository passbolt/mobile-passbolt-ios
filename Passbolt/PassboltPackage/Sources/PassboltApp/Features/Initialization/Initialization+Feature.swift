import Features

extension Initialization: Feature {
  
  public typealias Context = Void
  
  public static func environmentScope(
    _ rootEnvironment: RootEnvironment
  ) -> Void {
    Void()
  }
  
  public static func load(
    in context: Context,
    using features: FeatureFactory
  ) -> Initialization {
    Self(
      features: features
    )
  }
}

extension FeatureFactory {
  
  public var initialization: Initialization {
    instance(of: Initialization.self)
  }
}
