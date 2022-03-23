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

import CommonModels
import Environment
import TestExtensions
import XCTest

@testable import NetworkClient

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class NetworkRequestTests: XCTestCase {

  var cancellables: Cancellables!
  var authorizedSessionVariable: Result<AuthorizedNetworkSessionVariable, Error>!
  var domainSessionVariable: Result<DomainNetworkSessionVariable, Error>!
  var networking: Networking!
  var request: NetworkRequest<AuthorizedNetworkSessionVariable, TestCodable, TestCodable>!

  override func setUp() {
    super.setUp()
    cancellables = .init()
    authorizedSessionVariable = .failure(MockIssue.error())
    domainSessionVariable = .failure(MockIssue.error())
    networking = .placeholder
  }

  override func tearDown() {
    cancellables = nil
    authorizedSessionVariable = nil
    domainSessionVariable = nil
    networking = nil
    request = nil
    super.tearDown()
  }

  func test_request_withSessionError_fails() async throws {
    request = prepareRequest()
    var result: Error? = nil

    do {
      _ =
        try await request
        .makeAsync(using: .sample)
      XCTFail()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_request_withHTTPError_fails() async throws {
    networking.execute = { _, _ -> HTTPResponse in
      throw MockIssue.error()
    }
    authorizedSessionVariable = .success(
      AuthorizedNetworkSessionVariable(
        domain: "https://passbolt.com",
        accessToken: "",
        mfaToken: ""
      )
    )

    request = prepareRequest()
    var result: Error? = nil

    do {
      _ =
        try await request
        .makeAsync(using: .sample)
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_requestBodyAndResponseBody_withBodyMirroring_areEqual() async throws {
    networking.execute = { request, _ -> HTTPResponse in
      HTTPResponse(
        url: request.url ?? .test,
        statusCode: 200,
        headers: request.headers,
        body: request.body
      )
    }
    authorizedSessionVariable = .success(
      AuthorizedNetworkSessionVariable(
        domain: "https://passbolt.com",
        accessToken: "",
        mfaToken: ""
      )
    )

    request = prepareRequest()
    let bodySent: TestCodable = .sample
    let bodyReceived: TestCodable? =
      try await request
      .makeAsync(using: .sample)

    XCTAssertEqual(bodySent, bodyReceived)
  }

  func test_mfaRedirectHandler_isExecuted_whenRedirectIsReceived_andLocationMatchesDomain_andMfaErrorPath() async throws
  {
    networking.execute = { request, _ -> HTTPResponse in
      HTTPResponse(
        url: request.url ?? .test,
        statusCode: 302,
        headers: ["Location": "https://passbolt.com/mfa/verify/error.json"],
        body: .init()
      )
    }
    authorizedSessionVariable = .success(
      AuthorizedNetworkSessionVariable(
        domain: "https://passbolt.com",
        accessToken: "",
        mfaToken: ""
      )
    )
    domainSessionVariable = .success(
      DomainNetworkSessionVariable(domain: "https://passbolt.com")
    )

    var result: Void?

    request = prepareRequest(mfaRedirectionHandler: { _ in
      result = Void()
      return .init()
    })

    _ =
      try? await request
      .makeAsync(using: .sample)

    XCTAssertNotNil(result)
  }

  func test_mfaRedirectHandler_isNotExecuted_whenNotFound_received() async throws {
    networking.execute = { request, _ -> HTTPResponse in
      HTTPResponse(
        url: request.url ?? .test,
        statusCode: 404,
        headers: [:],
        body: .init()
      )
    }
    authorizedSessionVariable = .success(
      AuthorizedNetworkSessionVariable(
        domain: "https://passbolt.com",
        accessToken: "",
        mfaToken: ""
      )
    )
    domainSessionVariable = .success(
      DomainNetworkSessionVariable(domain: "https://passbolt.com")
    )

    var result: Void?

    request = prepareRequest(mfaRedirectionHandler: { _ in
      result = Void()
      return .init()
    })

    _ =
      try? await request
      .makeAsync(using: .sample)

    XCTAssertNil(result)
  }

  func test_mfaRedirectHandler_isNotExecuted_whenRedirectIsReceived_andLocationDoesNotMatchDomain() async throws {
    networking.execute = { request, _ -> HTTPResponse in
      HTTPResponse(
        url: request.url ?? .test,
        statusCode: 302,
        headers: ["Location": "https://bolt.com/mfa/verify/error.json"],
        body: .init()
      )
    }
    authorizedSessionVariable = .success(
      AuthorizedNetworkSessionVariable(
        domain: "https://passbolt.com",
        accessToken: "",
        mfaToken: ""
      )
    )
    domainSessionVariable = .success(
      DomainNetworkSessionVariable(domain: "https://passbolt.com")
    )

    var result: Void?

    request = prepareRequest(mfaRedirectionHandler: { _ in
      result = Void()
      return .init()
    })

    _ =
      try? await request
      .makeAsync(using: .sample)

    XCTAssertNil(result)
  }

  func test_mfaRedirectHandler_isNotExecuted_whenRedirectIsReceived_andNoLocationIsPresent() async throws {
    networking.execute = { request, _ -> HTTPResponse in
      HTTPResponse(
        url: request.url ?? .test,
        statusCode: 302,
        headers: [:],
        body: .init()
      )
    }
    authorizedSessionVariable = .success(
      AuthorizedNetworkSessionVariable(
        domain: "https://passbolt.com",
        accessToken: "",
        mfaToken: ""
      )
    )
    domainSessionVariable = .success(
      DomainNetworkSessionVariable(domain: "https://passbolt.com")
    )

    var result: Void?

    request = prepareRequest(mfaRedirectionHandler: { _ in
      result = Void()
      return .init()
    })

    _ =
      try? await request
      .makeAsync(using: .sample)

    XCTAssertNil(result)
  }

  func test_mfaRedirectHandler_isNotExecuted_whenRedirectIsReceived_andLocationDoesNotMatchMfaErrorPath() async throws {
    networking.execute = { request, _ -> HTTPResponse in
      HTTPResponse(
        url: request.url ?? .test,
        statusCode: 302,
        headers: ["Location": "https://passbolt.com/unknown.json"],
        body: .init()
      )
    }
    authorizedSessionVariable = .success(
      AuthorizedNetworkSessionVariable(
        domain: "https://passbolt.com",
        accessToken: "",
        mfaToken: ""
      )
    )
    domainSessionVariable = .success(
      DomainNetworkSessionVariable(domain: "https://passbolt.com")
    )

    var result: Void?

    request = prepareRequest(mfaRedirectionHandler: { _ in
      result = Void()
      return .init()
    })

    _ =
      try? await request
      .makeAsync(using: .sample)

    XCTAssertNil(result)
  }

  func test_mfaRedirectHandler_isNotExecuted_whenDomainSubject_publishesInvalidDomain() async throws {
    networking.execute = { request, _ -> HTTPResponse in
      HTTPResponse(
        url: request.url ?? .test,
        statusCode: 302,
        headers: ["Location": "https://passbolt.com/mfa/verify/error.json"],
        body: .init()
      )
    }
    authorizedSessionVariable = .success(
      AuthorizedNetworkSessionVariable(
        domain: "https://passbolt.com",
        accessToken: "",
        mfaToken: ""
      )
    )
    domainSessionVariable = .success(
      DomainNetworkSessionVariable(domain: "invalid$#@")
    )

    var result: Void?

    request = prepareRequest(mfaRedirectionHandler: { _ in
      result = Void()
      return .init()
    })

    _ =
      try? await request
      .makeAsync(using: .sample)

    XCTAssertNil(result)
  }

  func prepareRequest() -> NetworkRequest<AuthorizedNetworkSessionVariable, TestCodable, TestCodable> {
    .init(
      template: NetworkRequestTemplate { sessionVariable, requestVariable in
        .combined(
          .header("session", value: "\(sessionVariable)"),
          .jsonBody(from: requestVariable)
        )
      },
      responseDecoder: .bodyAsJSON(),
      using: networking,
      with: { try self.authorizedSessionVariable.get() }
    )
  }

  func prepareRequest(
    mfaRedirectionHandler: @escaping (MFARedirectRequestVariable) async -> MFARedirectResponse
  ) -> NetworkRequest<AuthorizedNetworkSessionVariable, TestCodable, TestCodable> {
    .init(
      template: NetworkRequestTemplate { sessionVariable, requestVariable in
        .combined(
          .header("session", value: "\(sessionVariable)"),
          .jsonBody(from: requestVariable)
        )
      },
      responseDecoder: .bodyAsJSON(),
      using: networking,
      with: {
        if let authorizedSessionVariable = self.authorizedSessionVariable {
          return try authorizedSessionVariable.get()
        }
        else {
          throw MockIssue.error()
        }
      }
    )
    .withAuthErrors(
      invalidateAccessToken: { /* NOP */  },
      authorizationRequest: { /* NOP */  },
      mfaRequest: { _ in /* NOP */ },
      mfaRedirectionHandler: mfaRedirectionHandler,
      sessionVariable: {
        if let domainSessionVariable = self.domainSessionVariable {
          return try domainSessionVariable.get()
        }
        else {
          throw MockIssue.error()
        }
      }
    )
  }
}
