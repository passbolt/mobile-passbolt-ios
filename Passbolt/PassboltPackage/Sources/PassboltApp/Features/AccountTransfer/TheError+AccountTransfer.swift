import Commons

extension TheError {
  
  public static func accountTransfer(
    underlyingError: Error? = nil
  ) -> Self {
    .init(
      identifier: .accountTransfer,
      underlyingError: underlyingError,
      extensions: [:]
    )
  }
}

extension TheError.ID {
  
  public static let accountTransfer: Self = "accountTransfer"
}
