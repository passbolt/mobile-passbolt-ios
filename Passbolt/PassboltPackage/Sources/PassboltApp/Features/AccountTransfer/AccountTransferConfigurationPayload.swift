internal struct AccountTransferConfigurationPayload {
  
  internal var transferID: String
  internal var pagesCount: Int
  internal var userID: String
  internal var authenticationToken: String
  internal var domain: String
  internal var hash: String
}

extension AccountTransferConfigurationPayload: Decodable {
  
  internal enum CodingKeys: String, CodingKey {
    
    case transferID = "transfer_id"
    case pagesCount = "total_pages"
    case userID = "user_id"
    case authenticationToken = "authentication_token"
    case domain = "domain"
    case hash = "hash"
  }
}
