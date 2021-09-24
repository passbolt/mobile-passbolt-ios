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

import Commons
import Environment
import TestExtensions
import XCTest

@testable import NetworkClient

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class NetworkRequestTests: XCTestCase {

  var cancellables: Cancellables!
  var sessionSubject: PassthroughSubject<NetworkSessionVariable, TheError>!
  var domainSubject: PassthroughSubject<DomainSessionVariable, TheError>!
  var networking: Networking!
  var request: NetworkRequest<NetworkSessionVariable, TestCodable, TestCodable>!

  override func setUp() {
    super.setUp()
    cancellables = .init()
    sessionSubject = .init()
    domainSubject = .init()
    networking = .placeholder
  }

  override func tearDown() {
    cancellables = nil
    sessionSubject = nil
    domainSubject = nil
    networking = nil
    request = nil
    super.tearDown()
  }

  func test_request_withFinishedSession_isNotExecuted() {
    request = prepareRequest()
    var completed: Bool = false

    request
      .make(using: .sample)
      .sink(
        receiveCompletion: { completion in
          switch completion {
          case .finished:
            completed = true

          case .failure:
            XCTFail("Unexpected behaviour")
          }
        },
        receiveValue: { _ in
          XCTFail("Unexpected behaviour")
        }
      )
      .store(in: cancellables)

    sessionSubject.send(completion: .finished)

    XCTAssertTrue(completed)
  }

  func test_request_withSessionError_fails() {
    request = prepareRequest()
    let errorSent: TheError = .testError()
    var completionError: TheError? = nil

    request
      .make(using: .sample)
      .sink(
        receiveCompletion: { completion in
          switch completion {
          case .finished:
            XCTFail("Unexpected behaviour")

          case let .failure(error):
            completionError = error
          }
        },
        receiveValue: { _ in
          XCTFail("Unexpected behaviour")
        }
      )
      .store(in: cancellables)

    sessionSubject.send(completion: .failure(errorSent))

    XCTAssertEqual(completionError?.identifier, errorSent.identifier)
  }

  func test_request_withHTTPError_fails() {
    networking.execute = { _, _ -> AnyPublisher<HTTPResponse, HTTPError> in
      Fail<HTTPResponse, HTTPError>(error: .canceled)
        .eraseToAnyPublisher()
    }

    request = prepareRequest()
    var completionError: TheError? = nil

    request
      .make(using: .sample)
      .sink(
        receiveCompletion: { completion in
          switch completion {
          case .finished:
            XCTFail("Unexpected behaviour")

          case let .failure(error):
            completionError = error
          }
        },
        receiveValue: { _ in
          XCTFail("Unexpected behaviour")
        }
      )
      .store(in: cancellables)

    sessionSubject.send(NetworkSessionVariable(domain: ""))

    XCTAssertEqual(completionError?.identifier, .httpError)
  }

  func test_requestBodyAndResponseBody_withBodyMirroring_areEqual() {
    networking.execute = { request, _ -> AnyPublisher<HTTPResponse, HTTPError> in
      Just(
        HTTPResponse(
          url: request.url ?? .test,
          statusCode: 200,
          headers: request.headers,
          body: request.body
        )
      )
      .setFailureType(to: HTTPError.self)
      .eraseToAnyPublisher()
    }

    request = prepareRequest()
    let bodySent: TestCodable = .sample
    var bodyReceived: TestCodable?

    request
      .make(using: .sample)
      .sink(
        receiveCompletion: { completion in
          switch completion {
          case .finished:
            break

          case .failure:
            XCTFail("Unexpected behaviour")
          }
        },
        receiveValue: { received in
          bodyReceived = received
        }
      )
      .store(in: cancellables)

    sessionSubject.send(NetworkSessionVariable(domain: ""))

    XCTAssertEqual(bodySent, bodyReceived)
  }

  func test_mfaRedirectHandler_isExecuted_whenRedirectIsReceived_andLocationMatchesDomain_andMfaErrorPath() {
    networking.execute = { request, _ -> AnyPublisher<HTTPResponse, HTTPError> in
      Just(
        HTTPResponse(
          url: request.url ?? .test,
          statusCode: 302,
          headers: ["Location": "https://passbolt.com/mfa/verify/error.json"],
          body: .init()
        )
      )
      .setFailureType(to: HTTPError.self)
      .eraseToAnyPublisher()
    }

    var result: Void!

    request = prepareRequest(mfaRedirectionHandler: { _ in
      result = Void()
      return Just(.init())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    })

    request
      .make(using: .sample)
      .sinkDrop()
      .store(in: cancellables)

    sessionSubject.send(NetworkSessionVariable(domain: ""))
    domainSubject.send(DomainSessionVariable(domain: "https://passbolt.com"))

    XCTAssertNotNil(result)
  }

  func test_mfaRedirectHandler_isNotExecuted_whenNotFound_received() {
    networking.execute = { request, _ -> AnyPublisher<HTTPResponse, HTTPError> in
      Just(
        HTTPResponse(
          url: request.url ?? .test,
          statusCode: 404,
          headers: [:],
          body: .init()
        )
      )
      .setFailureType(to: HTTPError.self)
      .eraseToAnyPublisher()
    }

    var result: Void!

    request = prepareRequest(mfaRedirectionHandler: { _ in
      result = Void()
      return Just(.init())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    })

    request
      .make(using: .sample)
      .sinkDrop()
      .store(in: cancellables)

    sessionSubject.send(NetworkSessionVariable(domain: ""))
    domainSubject.send(DomainSessionVariable(domain: "https://passbolt.com"))

    XCTAssertNil(result)
  }

  func test_mfaRedirectHandler_isNotExecuted_whenRedirectIsReceived_andLocationDoesNotMatchDomain() {
    networking.execute = { request, _ -> AnyPublisher<HTTPResponse, HTTPError> in
      Just(
        HTTPResponse(
          url: request.url ?? .test,
          statusCode: 302,
          headers: ["Location": "https://bolt.com/mfa/verify/error.json"],
          body: .init()
        )
      )
      .setFailureType(to: HTTPError.self)
      .eraseToAnyPublisher()
    }

    var result: Void!

    request = prepareRequest(mfaRedirectionHandler: { _ in
      result = Void()
      return Just(.init())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    })

    request
      .make(using: .sample)
      .sinkDrop()
      .store(in: cancellables)

    sessionSubject.send(NetworkSessionVariable(domain: ""))
    domainSubject.send(DomainSessionVariable(domain: "https://passbolt.com"))

    XCTAssertNil(result)
  }

  func test_mfaRedirectHandler_isNotExecuted_whenRedirectIsReceived_andNoLocationIsPresent() {
    networking.execute = { request, _ -> AnyPublisher<HTTPResponse, HTTPError> in
      Just(
        HTTPResponse(
          url: request.url ?? .test,
          statusCode: 302,
          headers: [:],
          body: .init()
        )
      )
      .setFailureType(to: HTTPError.self)
      .eraseToAnyPublisher()
    }

    var result: Void!

    request = prepareRequest(mfaRedirectionHandler: { _ in
      result = Void()
      return Just(.init())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    })

    request
      .make(using: .sample)
      .sinkDrop()
      .store(in: cancellables)

    sessionSubject.send(NetworkSessionVariable(domain: ""))
    domainSubject.send(DomainSessionVariable(domain: "https://passbolt.com"))

    XCTAssertNil(result)
  }

  func test_mfaRedirectHandler_isNotExecuted_whenRedirectIsReceived_andLocationDoesNotMatchMfaErrorPath() {
    networking.execute = { request, _ -> AnyPublisher<HTTPResponse, HTTPError> in
      Just(
        HTTPResponse(
          url: request.url ?? .test,
          statusCode: 302,
          headers: ["Location": "https://passbolt.com/unknown.json"],
          body: .init()
        )
      )
      .setFailureType(to: HTTPError.self)
      .eraseToAnyPublisher()
    }

    var result: Void!

    request = prepareRequest(mfaRedirectionHandler: { _ in
      result = Void()
      return Just(.init())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    })

    request
      .make(using: .sample)
      .sinkDrop()
      .store(in: cancellables)

    sessionSubject.send(NetworkSessionVariable(domain: ""))
    domainSubject.send(DomainSessionVariable(domain: "https://passbolt.com"))

    XCTAssertNil(result)
  }

  func test_mfaRedirectHandler_isNotExecuted_whenDomainSubject_publishesInvalidDomain() {
    networking.execute = { request, _ -> AnyPublisher<HTTPResponse, HTTPError> in
      Just(
        HTTPResponse(
          url: request.url ?? .test,
          statusCode: 302,
          headers: ["Location": "https://passbolt.com/mfa/verify/error.json"],
          body: .init()
        )
      )
      .setFailureType(to: HTTPError.self)
      .eraseToAnyPublisher()
    }

    var result: Void!

    request = prepareRequest(mfaRedirectionHandler: { _ in
      result = Void()
      return Just(.init())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    })

    request
      .make(using: .sample)
      .sinkDrop()
      .store(in: cancellables)

    sessionSubject.send(NetworkSessionVariable(domain: ""))
    domainSubject.send(DomainSessionVariable(domain: "https://bolt.com/mfa/verify/error.json"))

    XCTAssertNil(result)
  }

  func prepareRequest() -> NetworkRequest<NetworkSessionVariable, TestCodable, TestCodable> {
    .init(
      template: NetworkRequestTemplate { sessionVariable, requestVariable in
        .combined(
          .header("session", value: "\(sessionVariable)"),
          .jsonBody(from: requestVariable)
        )
      },
      responseDecoder: .bodyAsJSON(),
      using: networking,
      with: sessionSubject.eraseToAnyPublisher()
    )
  }

  func prepareRequest(
    mfaRedirectionHandler: @escaping (MFARedirectRequestVariable) -> AnyPublisher<MFARedirectResponse, TheError>
  ) -> NetworkRequest<NetworkSessionVariable, TestCodable, TestCodable> {
    .init(
      template: NetworkRequestTemplate { sessionVariable, requestVariable in
        .combined(
          .header("session", value: "\(sessionVariable)"),
          .jsonBody(from: requestVariable)
        )
      },
      responseDecoder: .bodyAsJSON(),
      using: networking,
      with: sessionSubject.eraseToAnyPublisher()
    )
    .withAuthErrors(
      authorizationRequest: { /* NOP */ },
      mfaRequest: { _ in /* NOP */ },
      mfaRedirectionHandler: mfaRedirectionHandler,
      sessionPublisher: domainSubject.eraseToAnyPublisher())
  }
}
