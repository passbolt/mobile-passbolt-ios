internal struct AccountTransferState {
  
  internal var configuration: AccountTransferConfigurationPayload? = nil
  internal var account: AccountTransferAccountPayload? = nil
  internal var parts: Array<AccountTransferPayloadPart> = .init()
}

extension AccountTransferState {
  
  internal var currentPage: Int {
    if transferFinished {
      return configuration?.pagesCount ?? 0
    } else {
      return (configuration == nil ? 0 : 1) + parts.count
    }
  }
  
  internal var transferFinished: Bool {
    configuration != nil && account != nil
  }
}
