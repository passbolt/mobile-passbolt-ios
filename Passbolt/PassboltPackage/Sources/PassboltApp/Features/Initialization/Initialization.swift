import Features

public struct Initialization {
  
  public var initialize: () -> Bool
}

extension Initialization: Feature {
  
  public typealias Environment = Void
  
  public static func load(
    in context: Environment,
    using features: FeatureFactory,
    cancellables: inout Array<AnyCancellable>
  ) -> Initialization {
    let diagnostics: Diagnostics = features.instance()
    
    return Self(
      initialize: {
        diagnostics.debugLog("Initialization")
        defer { diagnostics.debugLog("Initialization completed") }
        // initialize application features here
        return true // true if succeeded
      }
    )
  }
  
  #if DEBUG
  // placeholder implementation for mocking and testing, unavailable in release
  public static var placeholder: Self {
    Self(
      initialize: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
  #endif
}
