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

import FeatureScopes
import Features
import Foundation
import TestExtensions
import XCTest

@testable import PassboltAccountSetup

final class AccountKitImportTests: LoadableFeatureTestCase<AccountKitImport> {

  override class var testedImplementationScope: any FeaturesScope.Type { AccountTransferScope.self }

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.usePassboltAccountKitImport()
  }

  override func prepare() throws {
    set(AccountTransferScope.self)
    patch(
      \Accounts.storedAccounts,
      with: always([])
    )
    use(PGP.placeholder)
    use(Session.placeholder)
  }

  func test_importAccountKit_checkAccountKitFormat_shouldNotAllowEmptyString() async throws {

    let accountKitImport: AccountKitImport = try testedInstance()

    var result: Error?
    accountKitImport
      .importAccountKit("")
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    if let error = result as? AccountKitImportFailure {

      XCTAssertTrue(error.context.diagnosticsDescription.contains("The account kit is required."))

    }
    else {
      XCTFail("Error is not of type AccountKitImportFailure")
    }
  }

  func test_importAccountKit_checkAccountKitFormat_shouldNotAllowNonBase64() async throws {

    let accountKitImport: AccountKitImport = try testedInstance()

    var result: Error?
    accountKitImport
      .importAccountKit("this is not a base 64")
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    if let error = result as? AccountKitImportFailure {

      XCTAssertTrue(error.context.diagnosticsDescription.contains("The account kit should be a base 64 format."))

    }
    else {
      XCTFail("Error is not of type AccountKitImportFailure")
    }
  }

  func test_importAccountKit_extractPGPMessage_shouldNotExtractInvalidPGPMessage() async throws {

    patch(
      \PGP.readCleartextMessage,
      with: { _ in
        .failure(NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mocked error"]))
      }
    )

    let accountKitImport: AccountKitImport = try testedInstance()

    var result: Error?
    accountKitImport
      .importAccountKit("VGhpcyBpcyBub3QgYSB2YWxpZCBhY2NvdW50IGtpdA==")
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    if let error = result as? AccountKitImportFailure {
      XCTAssertTrue(error.context.diagnosticsDescription.contains("Failed to decode PGPMessage."))

    }
    else {
      XCTFail("Error is not of type AccountKitImportFailure")
    }
  }

  func test_importAccountKit_extractAccountKit_shouldNotExtractInvalidJSONKit() async throws {

    patch(
      \PGP.readCleartextMessage,
      with: { _ in .success(invalidAccountKitJSON) }
    )

    let accountKitImport: AccountKitImport = try testedInstance()
    let base64AccountKit = (invalidAccountKitJSON.data(using: .utf8)?.base64EncodedString())!
    var result: Error?
    accountKitImport
      .importAccountKit(base64AccountKit)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    if let error = result as? AccountKitImportFailure {
      XCTAssertTrue(error.context.diagnosticsDescription.contains("No Account kit found on the PGP message"))

    }
    else {
      XCTFail("Error is not of type AccountKitImportFailure")
    }
  }

  func test_importAccountKit_extractAccountKit_shouldNotExtractInvalidAccountKit() async throws {

    patch(
      \PGP.readCleartextMessage,
      with: { _ in .success(invalidAccountKitFormat) }
    )

    let accountKitImport: AccountKitImport = try testedInstance()
    let base64AccountKit = (invalidAccountKitFormat.data(using: .utf8)?.base64EncodedString())!

    var result: Error?
    accountKitImport
      .importAccountKit(base64AccountKit)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    if let error = result as? AccountKitImportFailure {
      XCTAssertTrue(error.context.diagnosticsDescription.contains("Cannot extract account kit from payload"))

    }
    else {
      XCTFail("Error is not of type AccountKitImportFailure")
    }
  }

  func test_importAccountKit_validateAccountKitSignature_shouldRejectInvalidSignature() async throws {
    patch(
      \PGP.readCleartextMessage,
      with: { _ in .success(accountKit) }
    )
    patch(
      \PGP.verifyMessage,
      with: { _, _, _ in
        .failure(NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mocked error"]))
      }
    )

    let accountKitImport: AccountKitImport = try testedInstance()
    let base64AccountKit = (accountKit.data(using: .utf8)?.base64EncodedString())!

    var result: Error?
    accountKitImport
      .importAccountKit(base64AccountKit)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    if let error = result as? AccountKitImportInvalidSignature {
      XCTAssertTrue(error.context.diagnosticsDescription.contains("Failed to validate signature"))

    }
    else {
      XCTFail("Error is not of type AccountKitImportInvalidSignature")
    }
  }

  func test_importAccountKit_validateAccountKitSignature_shouldNotValidateDuplicatedAccount() async throws {
    patch(
      \PGP.readCleartextMessage,
      with: { _ in .success(accountKit) }
    )

    patch(
      \PGP.verifyMessage,
      with: { _, _, _ in .success("accountKit") }
    )

    patch(
      \PGP.extractFingerprint,
      with: { _ in .success("fingerprint") }
    )

    patch(
      \Accounts.storedAccounts,
      with: always([transferedAccountWithProfile])
    )

    let accountKitImport: AccountKitImport = try testedInstance()
    let base64AccountKit = (accountKit.data(using: .utf8)?.base64EncodedString())!

    var result: Error?
    accountKitImport
      .importAccountKit(base64AccountKit)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    if let error = result as? AccountKitAccountAlreadyExist {
      XCTAssertTrue(error.context.diagnosticsDescription.contains("The account kit already exist."))

    }
    else {
      XCTFail("Error is not of type AccountKitAccountAlreadyExist")
    }
  }

  func test_importAccountKit_validateAccountKitSignature_shouldReturnTheAccountDataTransfer() async throws {
    patch(
      \PGP.readCleartextMessage,
      with: { _ in .success(accountKit) }
    )

    patch(
      \PGP.verifyMessage,
      with: { _, _, _ in .success("accountKit") }
    )

    patch(
      \PGP.extractFingerprint,
      with: { _ in .success("fingerprint") }
    )

    patch(
      \AccountImport.checkIfAccountExist,
      with: { _ in false }
    )

    let accountKitImport: AccountKitImport = try testedInstance()
    let base64AccountKit = (accountKit.data(using: .utf8)?.base64EncodedString())!

    var result: AccountTransferData?
    accountKitImport
      .importAccountKit(base64AccountKit)
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { accountData in
          result = accountData
        }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.userID, accountKitData.userID)
    XCTAssertEqual(result?.domain, accountKitData.domain)
  }
}

private let invalidAccountKitJSON = """
  -----BEGIN PGP SIGNED MESSAGE-----
  Hash: SHA512

  It is not a account kit
  -----BEGIN PGP SIGNATURE-----

  wsFzBAEBCgAGBQJluQC7ACEJEFsbMy7QZCbTFiEEDB0XYRENHjPJAG0aWxsz
  LtBkJtNRiQ//ckifre/5VeFfGarZGt3ph2VZvnfNaJ5bN7h5QS/3ymdHSG5I
  UYSrDTzHQmjlXNq57csM1YXoCcN2cILLvf9lvTTpQHdZc4OEt6O26bcq32T7
  LkXdvLuo+5phOAUBwwfuJDcxw9YcwSLI+0th8Mrl4ADcsqHos8G/XN6E1D3L
  2PSEZaRA8lcT7JlNIzz4PIHWxIV+jR5mGupsfuTW27DolPO7Z80lixX4Dwej
  NukoTbFHiAJr4Ddv3jOPXvM+KDu3OGvFIcMfOL/Bu0fsCAGWvgh4QURsfVwK
  epOWn8MBW6FT2Zknp8Xs/UE2aDFx+vXvBAXDDPhirADwm++1D5Dk3KZPgn1a
  uICh5vZY91hc5QrnS7I3kxJ+G47EynByOgBVe6wM74Y96sun67rTEgUhc125
  6hs/B7BCKhpu4/MzDs6FGuDDFOB/vVL5Pd//r30hJta9VcKGaCCVoDliWDDj
  snUmU+mITgUJZJaTyJ5hbUxyyrNexeNCPzuR7rQOztSvLbWGgAlTdvT09NQu
  6LSQun/CbLgiuRu4YXMuAjysJ0vO95qIA+bbTKKDZqn+R2bZA1XP95y21SvK
  TTP+8OIlMORYWJg40VMTNP/YMX9M9PP7jZGgHtOS0FdiZGXyut7OXLuPNb5g
  fEkkmr99xZIuU+KNO0pfjJzKswTfQ0xFKGo=
  =6cZE
  -----END PGP SIGNATURE-----
  """

private let invalidAccountKitFormat = """
  -----BEGIN PGP SIGNED MESSAGE-----
  Hash: SHA512

  {"domain":"https://test.passbolt.com"}}
  -----BEGIN PGP SIGNATURE-----

  wsFzBAEBCgAGBQJluQC7ACEJEFsbMy7QZCbTFiEEDB0XYRENHjPJAG0aWxsz
  LtBkJtNRiQ//ckifre/5VeFfGarZGt3ph2VZvnfNaJ5bN7h5QS/3ymdHSG5I
  UYSrDTzHQmjlXNq57csM1YXoCcN2cILLvf9lvTTpQHdZc4OEt6O26bcq32T7
  LkXdvLuo+5phOAUBwwfuJDcxw9YcwSLI+0th8Mrl4ADcsqHos8G/XN6E1D3L
  2PSEZaRA8lcT7JlNIzz4PIHWxIV+jR5mGupsfuTW27DolPO7Z80lixX4Dwej
  NukoTbFHiAJr4Ddv3jOPXvM+KDu3OGvFIcMfOL/Bu0fsCAGWvgh4QURsfVwK
  epOWn8MBW6FT2Zknp8Xs/UE2aDFx+vXvBAXDDPhirADwm++1D5Dk3KZPgn1a
  uICh5vZY91hc5QrnS7I3kxJ+G47EynByOgBVe6wM74Y96sun67rTEgUhc125
  6hs/B7BCKhpu4/MzDs6FGuDDFOB/vVL5Pd//r30hJta9VcKGaCCVoDliWDDj
  snUmU+mITgUJZJaTyJ5hbUxyyrNexeNCPzuR7rQOztSvLbWGgAlTdvT09NQu
  6LSQun/CbLgiuRu4YXMuAjysJ0vO95qIA+bbTKKDZqn+R2bZA1XP95y21SvK
  TTP+8OIlMORYWJg40VMTNP/YMX9M9PP7jZGgHtOS0FdiZGXyut7OXLuPNb5g
  fEkkmr99xZIuU+KNO0pfjJzKswTfQ0xFKGo=
  =6cZE
  -----END PGP SIGNATURE-----
  """

private let accountKit = #"""

  -----BEGIN PGP SIGNED MESSAGE-----
  Hash: SHA512

  {"domain":"https://test.passbolt.com","user_id":"d53c10f5-639d-5160-9c81-8a0c6c4ec856","username":"admin@passbolt.com","first_name":"Admin","last_name":"User","user_private_armored_key":"-----BEGIN PGP PRIVATE KEY BLOCK-----\n\n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\n=kkPj\n-----END PGP PRIVATE KEY BLOCK-----\n","user_public_armored_key":"-----BEGIN PGP PUBLIC KEY BLOCK-----\n\nxsFNBFY06pcBEADjYRuq05Zatu4qYtXmexbrwtUdakNJJHPlWxcusohdTLUm\nSXrt7LegXBE3OjvV9HbdBQfbpjitFp8eJw5krYQmh1+w/UYjb5Jy/A7ma3oa\nwzbVwNpLwuAafYma5LLLloZD/OpYKprhWfW9FHKyq6t+AcH5CFs/Hvixdrdb\nAO7K1/z6mgWcT6HBP5/dGTseAlrvUDTsW1kzo6qsrOWoUunrqm31umsvcfNR\nOtDKM16zgZl+GlYY1BxNcRKr1/AcZUrp4zdSSc6IXrYjJ+1kgHz/ZoSrKn5Q\niqEn7wQEveJu+jNGSv8jMvQgjq+AmzveJ/4f+RQirbe9JOeDgzX7NqloRil3\nI0FPFoivbRU0PHi4N2q7sN8eYpXxXzuL+OEq1GQe5fTsSotQTRZUJxbdUS8D\nfPckQaK79HoybTQAgA6mgQf/C+U0X2TiBUzgBuhayiW12kHmKyK02htDeRNO\nYs4bBMdeZhAFm+5C74LJ3FGQOHe+/o2oBktk0rAZScjizijzNzJviRB/3nAJ\nSBW6NSNYcbnosk0ET2osg2tLvzegRI6+NQJEb0EpByTMypUDhCNKgg5aEDUV\nWcq4iucps/1e6/2vg2XVB7xdphT4/K44ZeBHdFufhGQvs8rkAPzpkpsEWKgp\nTR+hdhbMmNiL984Ywk98nNuzgfkgpcP57xawNwARAQABzStQYXNzYm9sdCBE\nZWZhdWx0IEFkbWluIDxhZG1pbkBwYXNzYm9sdC5jb20+wsGlBBMBCgA4AhsD\nBQsJCAcDBRUKCQgLBRYCAwEAAh4BAheAFiEEDB0XYRENHjPJAG0aWxszLtBk\nJtMFAl0bmoYAIQkQWxszLtBkJtMWIQQMHRdhEQ0eM8kAbRpbGzMu0GQm0+fG\nD/9D1Y5ZQZ/tU6d9toiLHc0YA40juuBe4sVzUTS8bbRdZPb4LrEayQXCOglu\nLIOtsxicgsafu8MifcxKghN6YuO233v+URcrsCBskRZBYXWXGlebScK+MnqH\n6pq0Yr3qdyNy5rp5xS63XQD8IAKm6rF8o6EPoJozmX+SwQO3C+u/YwhpVqO4\nK/CD7JTHQjSt8BC/RhNdsnkxGfWm86jdzqflDTPl67+KIbRQ00gTdOTkqlPT\nYxMy/m6WWm3ea02MwcfT9N0/EK1QpWHirfjHezKJgt6lp11/kK2/0IvnZVZ+\nwbeoU8ent644VjyV/O56aioP2NwTtAgmeQKbC0tctCsTQ7ZFb/L+heqsRNe7\nawXIcyvVfD/9B4mAi/rcsEaZw86P3dXIciVxQNqszairb4NcrGsOzbF+cUpU\nJnClK95wh8pdQqydfcAaul62hl1/DSMBRUjee3pgK7wq9zNfF61+M5Xccddr\njSC05mTk6gpt+5OPNCWlzWhoPIsfw9PUZiw3fBagOzjO6WHq4oOlK37jPnwf\nUF88WWs7a6FlJ+TcTze4FBdlwAF5c3EJ2tMImbw/3SxuMu7VOVp46etbBVPt\niryLwsTuVsBedPUeNCUOLwYHb7YSdlmY5f5nzhrXqMMSVlrNQ2wTzNPs6bKO\n4HsYYNtAQVjORv12vWPWy6TO3M7BTQRWNOqXARAAnfsL2zimriO9wQXdsmAv\n6rdIGiWAEik3WDX/CiL28SI6H7t7TwqvyYSEXThylENuFjp1xnw4hchD31+B\n01d96GUBacjno0T8U4jKJ/xO8YF87rITfl8pKyTAY11RlYhnRTSnFJdC8H4o\nQZaWrZzdR/+OFNkOcs298OOdiafnJynmxVaG0CYoWFr00nosYDQPUwL6NwIk\nIq1BEaBW+Wo4RIUOZDs+7z9rKvYE7RREcnQ5vfSUeW4Kegoi/nSoakv0Fi4Y\nB0J8sEdfNFCEcht9z9xM+QrWRNdfnH8ySISXzxN4Y37KM1VLuqp3FiCz5Bic\nMNmp6+FYS9XJdVCNwJZIgd+MvXHk12pgvr5yL87HIgWg+zgra6Y3ck+akWL5\n8g+HYJ7ErLoGfITygCA2+B0Nvpk58C29KFk8ztAbgtlqXb6dinifuAlGHqR6\nlNBP/gG5rTE61FCGBwjica1wLEQNEwzOOpsZiVydyIyOyIyD0s+lY8MD7Eqt\nFkpjBUXLy8vH9qU7P+HUFmPHa7tia5oYQ3ETrYt/KHTF6gIENN2dYQ5BMfot\nWyiZW1Q7UVVqnW3mORhJ2nEG4d/z/Zh7s3cVMxEp72fh7vmwAnTS62cyXo/Z\nlxr2YzhPb08r4s8XHYbaHfkNDsxsSJ3VwBnxBVHdTKiJHz672Mx6T724UKb6\ncDEAEQEAAcLBjQQYAQoAIAIbDBYhBAwdF2ERDR4zyQBtGlsbMy7QZCbTBQJd\nG5qZACEJEFsbMy7QZCbTFiEEDB0XYRENHjPJAG0aWxszLtBkJtNODw//bBZh\nZHaEqsFPxJ++/odILeJJ5YGW4I9Ika6Jp5JyMCygWySV5LB5jD1yQfW91mf4\nBld6T1bQ1gyoNzWVuByytd8N7N8ENlYlVQOhcwAQ0pCN2AapJGrC0WVO6DfV\n2o3RX6YecC4Q0oEwo0p3Bn3I1cz7oFii6jz4oWTupqasUhWBIcfqfzvNE5Y/\ndFLDhUXaLe3Kp+cDoV2bSrENEcGgP7qv7BXulDShxtkQYEH6I+SW2syW75YD\nIlsYQWpcGSkFrPCAYf+GoPABcMKCTfoDrTTPQuFAh7vsrdE79v07vgKXI9KM\nhWiiQ+LkFJgoUNnw0crKiRCIXnvsi9vZq3XAeIxu0Nq7fB24WMJbByoGrNGC\nB3UenVDgossO9otJIcK3djw4MSkbufnKG+sDEql2yCMRSyywAh8trCnen0HI\nPBcaIrxIhdJUXzIt9gP2Fhif5NTqBQs1ueShV6qgTKbWGVodiXs4bbZonWBz\n3O42rOxxD58N0r1TNIGAHJhFVlr4yn1KToUmGJJPwe9cPUbiKT8siOxtlyPA\n2xtrbZ4AyDi/J40usm1PToOskzVKBy9cFhGTdW9385yh3AvZcq/DCINNEDXg\nyLbfYiCwjpI6BHVHWrqpUSGvhJlLvgC/iaG65UE88qwiJu2mk9x6fRMmhMec\nbyQ1rZo4HxWDQhbVdX8=\n=3ogW\n-----END PGP PUBLIC KEY BLOCK-----\n","server_public_armored_key":"-----BEGIN PGP PUBLIC KEY BLOCK-----\n\nxsBNBGE2GuoBCACz/+p/46zcDug8n9yM8OuyjtD5bw6sAUW9uyCr5xXaVER0\n3RkA/CJXvFq2LhPebUMpqAwK+Qz1e2G+1LzKNlF2WjR+v55BvC6K/YAsY60q\nKcK0q2oTlYre+nBzqcCqWiOUmWtqlcgm8BvqfcylbuwvbkT2Vih7Tj79ZlF+\nfF1CmNDakB7uboGKDEwShu+KinbNnP2JyKvGE9GsvW/opbbwGamvOIj7tfk3\nzU3RQZ1NfdcwmY4GWVfwB+bOjwAm4Cb63vKC/NDdYFd2WUBHpjW1BT7R4rXn\n9MTUcp7F6+5KAb2m/BxTT5xd+wDQsKFCaUfHbRLsC13x6ehiY/ijWUebABEB\nAAHNHVBhc3Nib2x0IDxhZG1pbkBwYXNzYm9sdC5jb20+wsB1BBABCAAfBQJh\nNhrqBgsJBwgDAgQVCAoCAxYCAQIZAQIbAwIeAQAKCRDKcb15+b7wECcHCACE\n1Tvbfni2SgFZJNnSRLoR4vO6k4mj6SlKifHUrxRnZlUgYjx+iIhcxhEkJoIk\npjDXDCvdv42YHUMt7VLpRVFNLwcprTxwiC+lWwR3UBxxbCqRNnss5L3fSwLI\nWcGg1bTeT8fQ7ewKYnF7UrSRo899KtbtFAtIZT3esEodIRsCCdrWsZpTQiSO\nW1r3scIPQc7I168UI3ZoW8yHCGseb/NJCJPEt1VE3HFyLI4kB1ZOJQps/gK7\nFEADCFYPS1GSBKe61c9PYrGV/4bnJ5tBo51tmnhO9NGH18xSKTK8vP5oHwKI\nS8PZORAdUwm01g7M0TliWiwD2203daM7ZPGl7nXwzsBNBGE2GuoBCACZ1EZm\nRgv6mgKNpltMCHFmq17C5hERlX9mTv4bxmdMnQaK828Sy8lD4yChrpptv0tk\ndICHfpFx4sx0ChBAI8KjOaW3Eyf51GEUIv/HmWMrRAoxgNlKGvx3Yi9gkBVE\nebzqMYVmuabh4z9Z/n8yuUN5UY7U0L186yoMIzgBWMXqM+O4P92T7nv8/vI5\npMsMus2Kd0g9a66+KVGnDsaCYfqnA/qEW4FhAM6sQuj+fX9j1iohnOEFeNYQ\nZ9tzy5arvfvWBoaZqKQjii9Dox8+ryK1cCgaMfOVc0PV+KQ+M32bf41VOYsZ\nXFMSZ03fCenp3m49qpLP4WMqpcAsW+CEI3PVABEBAAHCwF8EGAEIAAkFAmE2\nGuoCGwwACgkQynG9efm+8BA5awgAnU96HEV1R2POigeH9ZLhK7yxlZ7MU6ZM\nXGTz41l7Eev4LfkEmjFD7znWpW1WFeL3l1tGmS+dGrRhHpXFFVvHxjE/LtrZ\ncwvlAyHHwKrJBxs7Wtn724hgoTVpF2AMZ2rlQb/O43FxFRkpwBHDN5vOIS8F\n87kMNp8XJDXeJXvnGpeezl7js5BWddt/1/NxojOqIrdVKvXn0heOxI0RfWqO\nnGAUdGWvYs7ljWeYWV1wvOjNNWRXtk120WJKbh46gGTZPT44t+7F1QZfTBls\nd/spYTdxkklP0V6bdehCGsqvgkYVTSXASNvq3r72kYGkyLmazToFlS3GcPo7\nf75VjGlbBw==\n=6Bc2\n-----END PGP PUBLIC KEY BLOCK-----\n","security_token":{"code":"HUQ","color":"#f6f6f6","textcolor":"#000000"}}
  -----BEGIN PGP SIGNATURE-----

  asFzBAEBCgAGBQJluQC7ACEJEFsbMy7QZCbTFiEEDB0XYRENHjPJAG0aWxsz
  LtBkJtNRiQ//ckifre/5VeFfGarZGt3ph2VZvnfNaJ5bN7h5QS/3ymdHSG5I
  UYSrDTzHQmjlXNq57csM1YXoCcN2cILLvf9lvTTpQHdZc4OEt6O26bcq32T7
  LkXdvLuo+5phOAUBwwfuJDcxw9YcwSLI+0th8Mrl4ADcsqHos8G/XN6E1D3L
  2PSEZaRA8lcT7JlNIzz4PIHWxIV+jR5mGupsfuTW27DolPO7Z80lixX4Dwej
  NukoTbFHiAJr4Ddv3jOPXvM+KDu3OGvFIcMfOL/Bu0fsCAGWvgh4QURsfVwK
  epOWn8MBW6FT2Zknp8Xs/UE2aDFx+vXvBAXDDPhirADwm++1D5Dk3KZPgn1a
  uICh5vZY91hc5QrnS7I3kxJ+G47EynByOgBVe6wM74Y96sun67rTEgUhc125
  6hs/B7BCKhpu4/MzDs6FGuDDFOB/vVL5Pd//r30hJta9VcKGaCCVoDliWDDj
  snUmU+mITgUJZJaTyJ5hbUxyyrNexeNCPzuR7rQOztSvLbWGgAlTdvT09NQu
  6LSQun/CbLgiuRu4YXMuAjysJ0vO95qIA+bbTKKDZqn+R2bZA1XP95y21SvK
  TTP+8OIlMORYWJg40VMTNP/YMX9M9PP7jZGgHtOS0FdiZGXyut7OXLuPNb5g
  fEkkmr99xZIuU+KNO0pfjJzKswTfQ0xFKGo=
  =6cZE
  -----END PGP SIGNATURE-----
  """#

private let accountKitData = AccountTransferData(
  userID: AccountKitDTO.mock_admin.userID,
  domain: AccountKitDTO.mock_admin.domain,
  username: AccountKitDTO.mock_admin.username,
  firstName: AccountKitDTO.mock_admin.firstName,
  lastName: AccountKitDTO.mock_admin.lastname,
  avatarImageURL: nil,
  fingerprint: "fingerPrint",
  armoredKey: AccountKitDTO.mock_admin.privateKeyArmored
)

private let transferedAccount: Account = .init(
  localID: .init(rawValue: UUID.test.uuidString),
  domain: accountKitData.domain,
  userID: accountKitData.userID,
  fingerprint: accountKitData.fingerprint
)

private let transferedAccountWithProfile: AccountWithProfile = .init(
  account: transferedAccount,
  profile: .init(
    accountID: transferedAccount.localID,
    label: "Transfered",
    username: accountKitData.username,
    firstName: accountKitData.firstName,
    lastName: accountKitData.lastName,
    avatarImageURL: ""
  )
)
