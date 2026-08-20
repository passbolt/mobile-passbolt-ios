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
import NetworkOperations

internal struct ResourceFoldersFetchConfiguration: Sendable {

  internal let pageSize: Int
  internal let maximumConcurrentTasks: Int

  internal static let application: Self = .init(
    pageSize: 2_000,
    maximumConcurrentTasks: 3
  )

  internal static let `extension`: Self = .init(
    pageSize: 1_000,
    maximumConcurrentTasks: 3
  )
}

internal struct ResourceFoldersFetch: Sendable {

  internal typealias FetchPage = @Sendable (PaginationData) async throws -> ResourceFoldersFetchNetworkOperationResult

  /// How many times the page range may be extended after a page reports a larger total than page 1 did.
  /// Purely a work bound for a total that keeps growing - the checks in `attempt` decide whether the
  /// result may be returned.
  private static let maximumPageDiscoveryWaves: Int = 3
  /// How many times a set short of the largest reported total is re-fetched before the refresh fails.
  ///
  /// More than one because a *single* mid-fetch deletion is enough to spend a pass (see the note on the
  /// largest-total rule in `attempt`), so one budgeted retry would let two unlucky deletions in a row
  /// fail the whole refresh - and `refreshFolders` is awaited before `refreshResources`, so that stops
  /// resources syncing too. Three passes is still bounded work, and a genuine inconsistency is only
  /// delayed by one more pass.
  private static let maximumShortResultRetries: Int = 2

  private let configuration: ResourceFoldersFetchConfiguration
  private let fetchPage: FetchPage
  private let reportProgress: @Sendable (Double) -> Void

  /// - Parameters:
  ///   - configuration: Page size to request and how many page fetches may run at once - `.application`
  ///     or `.extension`.
  ///   - fetchPage: One page per call. Page 1 is fetched alone to establish the total, the rest
  ///     concurrently; a throw aborts the pass, so a partial set is never returned.
  ///   - reportProgress: Called with `pagesDone / totalPages` as pages arrive. Must be forward-only: the
  ///     denominator grows when a wave reveals more pages, and a pass that came back short restarts at
  ///     page 1.
  internal init(
    configuration: ResourceFoldersFetchConfiguration,
    fetchPage: @escaping FetchPage,
    reportProgress: @escaping @Sendable (Double) -> Void
  ) {
    self.configuration = configuration
    self.fetchPage = fetchPage
    self.reportProgress = reportProgress
  }
}

extension ResourceFoldersFetch {

  /// Outcome of one pass over the page range. `short` is the retriable one - it is the shape a mid-fetch
  /// change leaves behind, and the only failure a second pass can resolve.
  private enum Attempt {

    case complete(Array<ResourceFolderDTO>)
    case short(fetched: Int, expected: Int)
  }

  internal func execute() async throws -> Array<ResourceFolderDTO> {
    var remainingRetries: Int = Self.maximumShortResultRetries
    while true {
      switch try await self.attempt() {
      case .complete(let folders):
        return folders

      case .short(let fetched, let expected):
        guard remainingRetries > 0
        else {
          Diagnostics.logger.info("...folders fetch incomplete! (\(fetched)/\(expected) folders)")
          throw
            InternalInconsistency
            .error("Incomplete folders pagination")
            .recording(values: ["fetched": fetched, "expected": expected])
        }
        remainingRetries -= 1
        // The retry restarts at page 1, so progress restarts too; `reportProgress` is expected to be
        // forward-only (it is, via `reportRefreshProgress`), which turns that into a stall, not a regress.
        Diagnostics.logger.info("...folders fetch short (\(fetched)/\(expected)), retrying...")
      }
    }
  }

  /// One pass over the page range. Throws for anything a second pass cannot fix (a failed page, a range
  /// truncated at the discovery cap) and reports a short set as `short`.
  private func attempt() async throws -> Attempt {
    let pageSize: Int = self.configuration.pageSize
    let firstPage: PaginatedResponse<Array<ResourceFolderDTO>> =
      try await self.fetchPage(
        .init(
          page: 1,
          limit: pageSize
        )
      )

    let reportedCount: CriticalState<Int> = .init(firstPage.pagination.count)
    let effectivePageSize: Int = Self.effectivePageSize(of: firstPage, requested: pageSize)
    let requestedPageSize: Int = effectivePageSize > 0 ? effectivePageSize : pageSize
    @Sendable func pageCount(for total: Int) -> Int {
      guard effectivePageSize > 0, firstPage.items.count < total
      else { return 1 }
      return (total + effectivePageSize - 1) / effectivePageSize
    }

    let fetchedPages: CriticalState<Dictionary<Int, Array<ResourceFolderDTO>>> = .init(.init())
    let completedPages: CriticalState<Int> = .init(0)
    @Sendable func reportPageFetched() {
      let done: Int = completedPages.access { (count: inout Int) -> Int in
        count += 1
        return count
      }
      // The denominator grows when a later wave is discovered, which can only yield a smaller fraction;
      // a forward-only consumer ignores it, so the bar stalls rather than regressing.
      self.reportProgress(Double(done) / Double(pageCount(for: reportedCount.get())))
    }

    fetchedPages.access { (pages: inout Dictionary<Int, Array<ResourceFolderDTO>>) in
      pages[1] = firstPage.items
    }
    reportPageFetched()

    // Fetched in waves rather than one fixed range, so a total revised upward mid-fetch adds the pages it
    // implies. The wave cap only bounds the work if a total keeps growing; exiting on it leaves pages the
    // server implied unrequested, which the truncation check below turns into a failure.
    var fetchedThrough: Int = 1
    var wave: Int = 0
    while wave < Self.maximumPageDiscoveryWaves {
      let totalPages: Int = pageCount(for: reportedCount.get())
      guard fetchedThrough < totalPages
      else { break }

      // Concurrent: besides being faster, a shorter wall clock leaves less room for a server-side change
      // to shift rows across page boundaries. Keyed by page so the merge below stays ordered.
      let batchExecutor: BatchExecutor = .init(maxConcurrentTasks: self.configuration.maximumConcurrentTasks)
      for page: Int in (fetchedThrough + 1) ... totalPages {
        await batchExecutor.addOperation {
          let response: PaginatedResponse<Array<ResourceFolderDTO>> =
            try await self.fetchPage(
              .init(
                page: page,
                limit: requestedPageSize
              )
            )
          fetchedPages.access { (pages: inout Dictionary<Int, Array<ResourceFolderDTO>>) in
            pages[page] = response.items
          }
          reportedCount.access { (count: inout Int) in
            count = max(count, response.pagination.count)
          }
          reportPageFetched()
        }
      }
      // Propagates the first failure and cancels the rest, so nothing is returned. Includes a 404 from a
      // page past the end (the total shrank mid-fetch) - returning a short set would delete live folders.
      try await batchExecutor.execute()

      fetchedThrough = totalPages
      wave += 1
    }

    // Exiting on the wave cap rather than on the range being covered means pages the server implied were
    // never requested. A retry would face the same still-growing total, so this fails outright.
    let finalPageCount: Int = pageCount(for: reportedCount.get())
    guard fetchedThrough >= finalPageCount
    else {
      Diagnostics.logger.info(
        "...folders fetch truncated at the page discovery cap! (\(fetchedThrough)/\(finalPageCount) pages)"
      )
      throw
        InternalInconsistency
        .error("Truncated folders pagination")
        .recording(values: ["fetchedPages": fetchedThrough, "expectedPages": finalPageCount])
    }

    let pages: Dictionary<Int, Array<ResourceFolderDTO>> = fetchedPages.get()
    // Dropping repeated ids: a folder created or deleted mid-fetch can shift rows across a page boundary
    // and yield the same folder twice. Must happen here - the store's `topoSort` drops duplicates
    // silently, which would inflate the count and defeat the check below.
    let fetchedRowCount: Int = pages.values
      .reduce(into: 0) { (total: inout Int, page: Array<ResourceFolderDTO>) in
        total += page.count
      }
    var seenIDs: Set<ResourceFolder.ID> = .init()
    var folders: Array<ResourceFolderDTO> = .init()
    // Sized from what actually arrived, never from the reported total: `count` is server-supplied.
    folders.reserveCapacity(fetchedRowCount)
    for page: Int in 1 ... fetchedThrough {
      for folder: ResourceFolderDTO in pages[page] ?? .init() where !seenIDs.contains(folder.id) {
        seenIDs.insert(folder.id)
        folders.append(folder)
      }
    }

    // Measured against the largest total any page reported (see the note where it is accumulated), so a
    // row pushed across a page boundary by a mid-fetch change is caught rather than silently deleted by
    // the store. `execute` re-fetches a bounded number of times before failing.
    let expectedCount: Int = reportedCount.get()
    guard folders.count >= expectedCount
    else { return .short(fetched: folders.count, expected: expectedCount) }

    return .complete(folders)
  }

  /// The stride the server is actually paging by, in order of trust:
  /// - the rows page 1 delivered, when the block claims a narrower stride - they are in hand, so they
  ///   prove a stride at least that wide (a `limit` echoed as `1` alongside a full page);
  /// - the limit it echoed - unless the body it sent is shorter than both that limit and the total, which
  ///   is a server clamping rows to a smaller maximum of its own without adjusting `limit`; a first page
  ///   short of the limit can otherwise only mean it is also the last, and the total says it is not.
  ///   Trusting the echo there puts every later page on the wrong offset, and no pass can recover;
  /// - the requested page size, when the body is filled to it - a server that applies `limit` without
  ///   echoing it (`"limit": null`) looks exactly like that;
  /// - a short but non-empty body, which is that same clamping server with nothing echoed. Without this
  ///   the whole set reads as one short page, every refresh fails the completeness check, and resources
  ///   stop syncing with it.
  ///
  /// `0` means no stride: an empty body implies nothing, and deriving one from it would turn an empty
  /// page 1 with a non-zero total into one request per folder.
  // Internal (not private) so the stride rules can be unit-tested directly.
  internal static func effectivePageSize(
    of firstPage: PaginatedResponse<Array<ResourceFolderDTO>>,
    requested: Int
  ) -> Int {
    let rowCount: Int = firstPage.items.count
    let reportedLimit: Int = firstPage.pagination.limit
    let reportedCount: Int = firstPage.pagination.count
    let derived: Int
    if reportedLimit > 0 {
      let clampedRows: Bool = rowCount > 0 && rowCount < min(reportedLimit, reportedCount)
      derived = clampedRows ? rowCount : reportedLimit
    }
    else if rowCount >= requested {
      derived = requested
    }
    else if rowCount > 0, rowCount < reportedCount {
      derived = rowCount
    }
    else {
      derived = 0
    }
    return max(derived, rowCount)
  }
}
