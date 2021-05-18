internal struct AccountTransferAccountPayload {
  
  internal var userID: String
  internal var fingerprint: String
  internal var armoredKey: String
}

extension AccountTransferAccountPayload: Decodable {
  
  internal enum CodingKeys: String, CodingKey {
    
    case userID = "user_id"
    case fingerprint = "fingerprint"
    case armoredKey = "armored_key"
  }
}
