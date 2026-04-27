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

/// Prepared FTS5 search queries. Input is sanitized by escaping double quotes and wrapping in
/// a phrase literal ("…"*), which neutralizes FTS5 query operators (AND, OR, NOT, NEAR) in user input.
/// Trigram index requires minimum 3 characters, so `useTrigramIndex` indicates whether the trigram
/// query should be included.
internal struct FTSQueryParameters {

  internal let unicodeQuery: String
  internal let trigramQuery: String
  internal let useTrigramIndex: Bool
}

/// Prepares FTS5 query parameters from raw user input text.
/// Returns `nil` when text is empty (no filter needed).
/// - Parameters:
///   - text: Raw user search input.
///   - columnFilter: Optional FTS5 column filter (e.g., "name", "uris"). When provided, queries
///     are prefixed with `{column} :` to restrict matching to that column.
/// - Returns: `FTSQueryParameters` containing sanitized queries for both unicode and trigram indexes, and a flag indicating whether to use the trigram index.
internal func prepareFTSQueries(
  text: String,
  columnFilter: String? = nil
) -> FTSQueryParameters? {
  guard !text.isEmpty else { return nil }

  let sanitizedText: String = text.replacingOccurrences(of: "\"", with: "\"\"")
  let columnPrefix: String = columnFilter.map { "{\($0)} : " } ?? ""

  return FTSQueryParameters(
    unicodeQuery: "\(columnPrefix)\"\(sanitizedText)\"*",
    trigramQuery: "\(columnPrefix)\"\(sanitizedText)\"",
    useTrigramIndex: sanitizedText.count >= 3
  )
}
