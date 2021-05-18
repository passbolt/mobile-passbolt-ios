import Commons

internal struct AccountTransferPayloadPart {

  internal let version: String
  internal let page: Int
  internal let payload: String
}

extension AccountTransferPayloadPart {
  
  internal func from(
    qrCode string: String
  ) -> Result<Self, TheError> {
    placeholder("TODO: [PAS-71] - complete data processing")
  }
}
