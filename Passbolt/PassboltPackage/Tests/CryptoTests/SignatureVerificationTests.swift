//
// Passbolt - Open source password manager for teams
// Copyright (c) 2021 Passbolt SA
//
// This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General
// Public License (AGPL) as published by the Free Software Foundation version 3.
//
// The name "Passbolt" is a registered trademark of Passbolt SA, and Passbolt SA hereby declines to grant a trademark
// license to "Passbolt" pursuant to the GNU Affero General Public License version 3 Section 7(e), without a separate
// agreement with Passbolt SA.
//
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License along with this program. If not,
// see GNU Affero General Public License v3 (http://www.gnu.org/licenses/agpl-3.0.html).
//
// @copyright     Copyright (c) Passbolt SA (https://www.passbolt.com)
// @license       https://opensource.org/licenses/AGPL-3.0 AGPL License
// @link          https://www.passbolt.com Passbolt (tm)
// @since         v1.0
//

import Accounts
import Commons
import Crypto
import Security
import TestExtensions
import XCTest

final class SignatureVerificationTests: XCTestCase {

  func test_verification_withExistingToken_Succeeds() {
    let verification: SignatureVerfication = .rssha256()
    let key: String = publicKey.stripArmoredFormat()

    var components: Array<String> = validToken.components(separatedBy: ".")

    guard let keyData: Data = .init(base64Encoded: key),
      let signature: Data = components.popLast()?.base64DecodeFromURLEncoded(),
      let signedData: Data = components.joined(separator: ".").data(using: .utf8)
    else {
      XCTFail("Unexpected failure")
      return
    }

    let result: Result<Void, TheError> = verification.verify(
      signedData,
      signature,
      keyData
    )

    XCTAssertSuccess(result)
  }

  func test_verification_withToken_InvalidSignature_Fails() {
    let verification: SignatureVerfication = .rssha256()
    let key: String = publicKey.stripArmoredFormat()

    var components: Array<String> = tokenWithInvalidSignature.components(separatedBy: ".")

    guard let keyData: Data = .init(base64Encoded: key),
      let signature: Data = components.popLast()?.base64DecodeFromURLEncoded(),
      let signedData: Data = components.joined(separator: ".").data(using: .utf8)
    else {
      XCTFail("Unexpected failure")
      return
    }

    guard
      case let Result.failure(error) = verification.verify(
        signedData,
        signature,
        keyData
      )
    else {
      XCTFail("Unexpected success")
      return
    }

    XCTAssertEqual(error.identifier, TheError.ID.signatureError)
  }

  func test_verification_withToken_MissingSignature_Fails() {
    let verification: SignatureVerfication = .rssha256()
    let key: String = publicKey.stripArmoredFormat()

    var components: Array<String> = tokenWithNoSignature.components(separatedBy: ".")

    guard let keyData: Data = .init(base64Encoded: key),
      let signature: Data = components.popLast()?.base64DecodeFromURLEncoded(),
      let signedData: Data = components.joined(separator: ".").data(using: .utf8)
    else {
      XCTFail("Unexpected failure")
      return
    }

    guard
      case let Result.failure(error) = verification.verify(
        signedData,
        signature,
        keyData
      )
    else {
      XCTFail("Unexpected success")
      return
    }

    XCTAssertEqual(error.identifier, TheError.ID.signatureError)
  }

  func test_verification_withExistingToken_andServerRSAPublicKey_Succeeds() {
    let verification: SignatureVerfication = .rssha256()
    let key: String = shortRsaPublicKey.stripArmoredFormat()

    var components: Array<String> = shortJwt.components(separatedBy: ".")

    guard let keyData: Data = .init(base64Encoded: key),
      let signature: Data = components.popLast()?.base64DecodeFromURLEncoded(),
      let signedData: Data = components.joined(separator: ".").data(using: .utf8)
    else {
      XCTFail("Unexpected failure")
      return
    }

    let result: Result<Void, TheError> = verification.verify(
      signedData,
      signature,
      keyData
    )

    XCTAssertSuccess(result)
  }

  func test_verification_withExistingToken_andLongerServerRSAPublicKey_Succeeds() {
    let verification: SignatureVerfication = .rssha256()
    let key: String = longRsaPublicKey.stripArmoredFormat()

    var components: Array<String> = longJwt.components(separatedBy: ".")

    guard let keyData: Data = .init(base64Encoded: key),
      let signature: Data = components.popLast()?.base64DecodeFromURLEncoded(),
      let signedData: Data = components.joined(separator: ".").data(using: .utf8)
    else {
      XCTFail("Unexpected failure")
      return
    }

    let result: Result<Void, TheError> = verification.verify(
      signedData,
      signature,
      keyData
    )

    XCTAssertSuccess(result)
  }
}

private let validToken: String = """
  eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJpb3MiLCJleHAiOjE1MTYyMzkwMjIsImlzcyI6IlBhc3Nib2x0Iiwic3ViIjoiMTIzNDU2Nzg5MCJ9.HXr5rsntdBCQCzjLmo_FQAgHhPBiUn9b55txhkuSLbESCUu7ErtSf2gnKnZRNvdF3xi8KSOtf-NzkaVBSjFPa_IgSP1wZj9i0AmtygC8WGsepR5d-7ZYTglWcOAlUIOBA_0jLZj6RiE2YYER5biCyP-9XBTig4HvyEWmTwtf88QIoFy0pjlH0sA0T8YJT1IIR6ZuvoRbBcFpAXjFOi5aBk02Jdf3J9BIfUiQqup4N3P4ny5FPAjeCyjBr7zTy6Cq1G350ihtDYii6oXoAGgxAunrxy3VQ4djgtA9bu3Z4Cktyw919FE2Rwgg9pCzSyvQPGEMZklh-PrkFuV5L7SRZD3i-OGVQMdd173k3k0QZHlMWeLhB23glBIGhNvI7dM2IkWt-8V0cEVE3oNUi6Mp43EdpCQC8U8Q54tK8W8SbLx2-V31bgy0HTK_FLbppdAcelbw5dMAnSZt5qhH0-J2JfIZLQzp4_B7uvz3WErqqSD42rGZ2OQTuYx_BxTRfNV1WZs_kuAua0AU_BRxviXJUoWUHVeGXTwGvcFJknQBCgnwmkFM0koWDAfEeg0WZ8vcfmtamtoK8AAxhpPjUPaFsbZ2ojRPkVuZ0m7qkYkraqH7fewdKC4dHdgoyWVJ-UdHI6p4F6Vds08wP70Kf-Fq3iBEVykzdMZELnlKcJI81eA
  """

private let tokenWithInvalidSignature: String = """
  eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJpb3MiLCJleHAiOjE1MTYyMzkwMjIsImlzcyI6IlBhc3Nib2x0Iiwic3ViIjoiMTIzNDU2Nzg5MCJ9.invalidSignature
  """

private let tokenWithNoSignature: String = """
  eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJpb3MiLCJleHAiOjE1MTYyMzkwMjIsImlzcyI6IlBhc3Nib2x0Iiwic3ViIjoiMTIzNDU2Nzg5MCJ9
  """

private let publicKey: String = """
  -----BEGIN PUBLIC KEY-----
  MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA07sAMRiJeGl2djgb7pYB
  yWsYQ8kPH4HfTdQHj21980spnhPp1kUL7/jNUoMC8g+AbvL+5JZvC6d8QPHbJaup
  CwdURGAdUfA/4Gdm0OxFFvgy0MoPW6sCjZgVZZcKTjQLMgKwnZBNk0EJRm+Q1iC/
  eYZa3rUF/JTfCJUTmqk9EV8ofJum8ZHZiSUZ2ZqzPuWyG7u5+XeTM2FpHLNp6Xut
  P1jyKbj3MEyo8IWII3C33bBvGdckoSgweLNnlJHy4cneJWoOv7oQE0TKF0qaylcq
  Tz16oN1hkX5KNaEuBInhxoqQ6fun5HHR7u9EsyqPx/fkVMk3ZC/1AGDldbk5cbfC
  2zPyLUXWZp9xCXlJ4rC/tiQZqg+EF2OZw9UWZj7U1KAqFSOxGebn628uuQbame2l
  SE0311BuMUNFBtaIBc91Oa+jsYskdj+IBOhRM+N11dZUabH+OSNGZ6Bx5PLRk4yB
  tEEOjqF/P46JZmJrwuGG//SJF+3g6HlMmJF6R88BZSa5JRY/oul9hI2EUYQuzUMA
  WsOR/Rbgwi5Dye/xfM0d/oyCY5dOAVrtChh7VITa+x+niJwWTbBTtsMWgjixN11W
  WrU68SHJysMn2VdAVKm1XyvrACBfVqQmeksojM+0XR2FNUT2aRJhZkS08kvUEpWZ
  1yLWucYSll29BM1G1cL/jKkCAwEAAQ==
  -----END PUBLIC KEY-----
  """

private let shortJwt: String = """
  eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvcGFzc2JvbHQuZGV2XC8iLCJzdWIiOiI4ZDA0Y2Y5OC03MTZiLTVmNmQtOWZlOC1jMTMwZjg5OTI2NDYiLCJleHAiOjE2MjM2NzY2Njd9.nepYHRPJZP90UVLTLCLvDSIg_HKqvkg-K0ZwlXrVoaqsGmMnkdbN79OOiEB4faek794XIUmytKcPSNg3-qE7pIi3l6fo4ImJjU-HkLgChWT84KGjq67kMA4hBuM0dar2T6fDrI7hWzWN3HvqTJ0B5qEJDAq1ja6t9at6wE5cfLA
  """

private let shortRsaPublicKey: String = """
    -----BEGIN PUBLIC KEY-----\nMIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDJUs/H6KlixD3zmn/XRZUtphuS\n+LKOsgdmRH/+pE0L2u/Gb7mqHy5Yy6u10zXduLQiGAeNqJrEwsrjvWOYKqvyZvMW\n9L1eUuVFVum8MlNvLK5XDx+U3uVs6vflqYXeaxNhKW31IQRy7O9bd8/BYbxDqSes\n7OGbB3Qhpu2eb1TIhQIDAQAB\n-----END PUBLIC KEY-----\n
  """

private let longJwt: String = """
  eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvcGFzc2JvbHQuZGV2XC8iLCJzdWIiOiI4ZDA0Y2Y5OC03MTZiLTVmNmQtOWZlOC1jMTMwZjg5OTI2NDYiLCJleHAiOjE2MjM2Nzg5ODN9.GR5eJhMpTKbL12-6hpxSK2LImFvdcyrd-I8qJ8fTaKlygAHe60UFg5d4HyFj1FTyBgxw2Y719L5l6LUNKeG90nuTKinw4012GJKRXWVHRReoh8YThQlAO9Xyx3C9VdCBdoyMORV7ppvHBAyr0jiXjM1nMF2VQ1HEhLqELjMfvEOTc03H6xbC4ZBagGDMzahe8KEpClMMcSCptUfT5gObTYDMNPkTuyIEGB2jR3VfTUCtlIwOfZ85Hmh_qkFwqJbF5zHRkiNgq7ss-m5_HCQosWDN86wK-xBmG98E0LThV4HVvSGB3m0xTdp20uZKtuey93TRl12X8yPsNDEdOCHMp3bc7nAf3y9hqYRf74nxDDAtFVbh1Oo3dw97J22RvtiH_m-78mQTsDax3ayFCt9li2Qsw-RhdzsVdEqkXguJMl_dcPfR4uhJBzLPDYTjw8wHJqngB4-vZpnaOEV-XXze0iyBeNaJar80QCN2FhUDP6oUfkYwUL522N8r-3friUlPWQpZm7MrVW1Mt5EJyC_38kiEJnT8DfsNkJxhOt34vGXbKyTe43tQE_VlNif4M_wmOGXWhEUxDq1KklvLo2qkT6DhW0XkMBVLd64PO-CVtjQ_f5RbmZCkSQhtFu_C9ewfVDvKP-U0e0NWC6gNUiH4K4zlP-kB_NIeoatpyzvDT1I
  """

private let longRsaPublicKey: String = """
  -----BEGIN PUBLIC KEY-----\nMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA1JfiaaGxGmTB9FuHLyIp\neQFWEBmANy9Sy3ijkg7XFXy2EFiB547vijStrAme2W+wrMDhEvBNUoOSuLaIkddv\nKJ5mUgNk75MKVNf+OJMRzeu/zRMrLciNG57V7n+mO0pMgjnfJFPlNn7GTX0knozV\nd/J1OdVr4fZTDcOmwy4W1JDSSNnSt1zdJxwVBiBTQGigTbwyg1BoN1a4QMmty6xX\nZBDtxKTGc+H1Bmkx2AcCFii5ePTv4fRYwcCdmW5DpFExGldHC/S3l+iRUT0FfrgL\n/M18ruU2pLeweIOfLaChCr8m8KnK5ByLZF2FtXOB0BPehleY6lvX8KgoIlRD35Dr\nf/VhuuHfj00a+2mBvTNzmjGljxBGvQ7v43zV5mFsoXTn+BXxq6HeavYKN1bKDDBC\n05JItIoke1aaPo5zleFlZwmCHNva2h+//iLDdEH2JjsIxzGOJv0Rb8isTLo5NMU4\nrUJwQ38V9TFzwrLcgUzT7Rf4W6cK4VKm6N3fDKar9mvmqNOyFGSFy6KSoc+Woszc\nivQOUs2hManLs560RNCMcjAtAcppxB3i6q7EwKOoKUEGIRHRAt3dXF1B68rErmJk\nm7VHaejSBsp53Ale1Ux+QK3knmY3shdGHA1FRX5uLic33Yc1DyjI2ywA8YhYsm/x\ngPNVo1AEfr4ADYdu04Mwr4MCAwEAAQ==\n-----END PUBLIC KEY-----\n
  """
