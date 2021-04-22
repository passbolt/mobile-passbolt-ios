import Features

public struct Initialization {
  
  public var initialize: () -> Bool
}

extension Initialization {
  
  internal init(
    features: FeatureFactory
  ) {
    self.init(
      initialize: {
        // initialize application features here
        return true // true if succeeded
      }
    )
  }
}
