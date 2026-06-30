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

import XCTest

import Dispatch

import class Foundation.NSLock

/// Standard metric set captured by Passbolt async benchmarks.
///
/// Returns fresh metric instances on each call because `XCTMetric` values are
/// stateful and not reusable across measurements. `XCTCPUMetric` and
/// `XCTStorageMetric` only report on physical devices; they are inert (not
/// failing) in the simulator.
public func benchmarkMetrics() -> Array<XCTMetric> {
  [
    XCTClockMetric(),
    XCTMemoryMetric(),
    XCTCPUMetric(),
    XCTStorageMetric()
  ]
}

extension XCTestCase {

  /// Runs `measure(metrics:options:)` over an asynchronous operation.
  ///
  /// `XCTestCase.measure` only accepts a synchronous block, so each measurement
  /// iteration bridges to async by spawning a `Task` and blocking the calling
  /// thread until it completes. This is safe only when the operation does not
  /// require the thread that calls `measure` (typically the main thread) to make
  /// progress — i.e. it must not hop back to the main actor. Benchmarked features
  /// should therefore run their work off the main actor.
  ///
  /// - Parameters:
  ///   - metrics: Metrics to capture (defaults to ``benchmarkMetrics()``).
  ///   - options: Measurement options (iteration count, etc.).
  ///   - iterations: Measured iterations (lower it for very heavy benchmarks).
  ///   - operation: The asynchronous work to measure.
  public func measureAsync(
    metrics: Array<XCTMetric> = benchmarkMetrics(),
    options: XCTMeasureOptions = .default,
    iterations: Int = 20,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ operation: @escaping @Sendable () async throws -> Void
  ) {
    options.iterationCount = iterations
    self.measure(metrics: metrics, options: options) {
      let semaphore: DispatchSemaphore = .init(value: 0)
      let failure: AsyncBenchmarkFailureBox = .init()
      // Detached so the operation never inherits the (main-actor) caller context:
      // `measure` runs the block on the test thread and we block it on the semaphore
      // below, so a main-actor hop would deadlock. See the constraint noted above.
      Task.detached {
        do {
          try await operation()
        }
        catch {
          failure.store(error)
        }
        semaphore.signal()
      }
      semaphore.wait()
      if let error: Error = failure.value {
        XCTFail(
          "Async benchmark operation threw: \(error)",
          file: file,
          line: line
        )
      }
    }
  }
}

/// Thread-safe holder for an error captured inside a measured iteration.
private final class AsyncBenchmarkFailureBox: @unchecked Sendable {

  private let lock: NSLock = .init()
  // swift-format-ignore: NoLeadingUnderscores
  private var _value: Error?

  func store(_ error: Error) {
    self.lock.withLock { self._value = error }
  }

  var value: Error? {
    self.lock.withLock { self._value }
  }
}
