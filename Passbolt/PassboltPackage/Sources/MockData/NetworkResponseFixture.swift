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

import class Foundation.Bundle
import struct Foundation.Data
import class Foundation.JSONDecoder
import struct Foundation.URL

/// Loads standardized JSON network-response dumps bundled in `MockData`.
///
/// Fixtures are verbatim Passbolt API response envelopes (`{"header":…,"body":…}`)
/// stored under `Sources/MockData/Fixtures` and addressed by their path relative
/// to that directory (e.g. `"Benchmark/small/users.json"`). Decoding reuses the
/// app's network configuration (`JSONDecoder` with `.iso8601` dates) and returns
/// the `body`, mirroring what the real network operations produce.
///
/// See `Fixtures/README.md` for the directory convention and the git-lfs submodule
/// that provides large datasets under the same tree.
public enum NetworkResponseFixture {

  public enum Failure: Error, CustomStringConvertible {

    case notFound(String)
    case decodingFailed(String, underlying: Error)

    public var description: String {
      switch self {
      case .notFound(let path):
        return "Network response fixture not found: \(path)"
      case .decodingFailed(let path, let underlying):
        return "Failed to decode network response fixture \(path): \(underlying)"
      }
    }
  }

  /// Root directory of the bundled fixtures tree.
  private static var root: URL? {
    Bundle.module.resourceURL?.appendingPathComponent("Fixtures", isDirectory: true)
  }

  /// A decoder matching the app's network response decoder configuration.
  /// Created per call because `JSONDecoder` is not `Sendable`.
  private static func makeDecoder() -> JSONDecoder {
    let decoder: JSONDecoder = .init()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }

  /// Minimal response envelope: only `body` is decoded, `header` is ignored.
  private struct Envelope<Body: Decodable>: Decodable {
    let body: Body
  }

  /// Whether a fixture exists at the given relative path. Use to skip benchmarks
  /// that depend on the optional large (git-lfs submodule) dataset.
  public static func exists(_ relativePath: String) -> Bool {
    guard let url: URL = self.root?.appendingPathComponent(relativePath)
    else { return false }
    return (try? url.checkResourceIsReachable()) ?? false
  }

  /// Resolves the on-disk URL for a fixture, throwing if it is absent.
  public static func url(_ relativePath: String) throws -> URL {
    guard
      let url: URL = self.root?.appendingPathComponent(relativePath),
      (try? url.checkResourceIsReachable()) == true
    else { throw Failure.notFound(relativePath) }
    return url
  }

  /// Loads the raw bytes of a fixture.
  public static func data(_ relativePath: String) throws -> Data {
    try Data(contentsOf: self.url(relativePath))
  }

  /// Decodes the `body` of a fixture envelope.
  public static func decodeBody<Body>(
    _ relativePath: String,
    as _: Body.Type = Body.self
  ) throws -> Body
  where Body: Decodable {
    try self.decodeBody(from: self.data(relativePath), as: Body.self, path: relativePath)
  }

  /// Decodes the `body` of an envelope from already-loaded bytes.
  ///
  /// Separating loading from decoding lets benchmarks cache the bytes once and
  /// measure only the recurring decode cost.
  public static func decodeBody<Body>(
    from data: Data,
    as _: Body.Type = Body.self,
    path: String = "<in-memory>"
  ) throws -> Body
  where Body: Decodable {
    do {
      return try self.makeDecoder().decode(Envelope<Body>.self, from: data).body
    }
    catch {
      throw Failure.decodingFailed(path, underlying: error)
    }
  }
}
