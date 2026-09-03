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
import FeatureScopes
import Features
import Localization
import OSFeatures

// MARK: - Interface

/// Deprecation announcement, identified to allow silencing it independently of any other.
internal struct DeprecationNotice: Equatable, Sendable {

  internal let identifier: String
  internal let title: DisplayableString
  /// Message paragraphs, rendered in order. Inline markdown (`**bold**`) applies.
  internal let messages: Array<DisplayableString>
}

internal struct DeprecationCheck: Sendable {

  /// A notice to be presented or `none` when there is nothing pending.
  internal var pendingNotice: @Sendable () -> DeprecationNotice?
  /// Withholds given notice for the rest of the application run, not persisting it.
  /// The splash screen is reached more than once per run - after authorization, for
  /// example - and an announcement is meant to be seen only on the first entry.
  internal var markPresented: @Sendable (DeprecationNotice) -> Void
  /// Silences given notice permanently, not affecting any other.
  internal var silence: @Sendable (DeprecationNotice) -> Void
}

// MARK: - Implementation

extension DeprecationCheck {

  /// Major system version required by the upcoming releases.
  /// Bumping it makes the notice appear again, silenced or not.
  internal static var upcomingMinimumSystemVersion: Int { 17 }

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    let applicationMeta: ApplicationMeta = features.instance()
    let silencedNotices: SilencedDeprecationNoticesStoredProperty = try features.instance()
    // identifiers of notices already presented in this application run
    let presentedNotices: CriticalState<Set<String>> = .init(.init())

    @Sendable nonisolated func systemSupportNotice() -> DeprecationNotice? {
      let requiredSystemVersion: Int = Self.upcomingMinimumSystemVersion
      guard applicationMeta.operatingSystemMajorVersion() < requiredSystemVersion
      else { return .none }

      return DeprecationNotice(
        identifier: "system-support-\(requiredSystemVersion)",
        title: "deprecation.system.support.title",
        messages: [
          "deprecation.system.support.message",
          "deprecation.system.support.message.action",
        ]
      )
    }

    @Sendable nonisolated func pendingNotice() -> DeprecationNotice? {
      // ordered by importance, only the first pending one is presented
      let notices: Array<DeprecationNotice> = [
        systemSupportNotice()
      ]
      .compactMap { (notice: DeprecationNotice?) -> DeprecationNotice? in notice }

      let silenced: Array<String> = silencedNotices.get(withDefault: .init())
      let presented: Set<String> = presentedNotices.get()
      return notices.first { (notice: DeprecationNotice) -> Bool in
        !silenced.contains(notice.identifier) && !presented.contains(notice.identifier)
      }
    }

    @Sendable nonisolated func markPresented(
      _ notice: DeprecationNotice
    ) {
      presentedNotices.access { (presented: inout Set<String>) -> Void in
        presented.insert(notice.identifier)
      }
    }

    @Sendable nonisolated func silence(
      _ notice: DeprecationNotice
    ) {
      // exclusive in-memory read-modify-write, persisting is serialized by MainActor callers
      silencedNotices.variable.mutate { (silenced: inout Array<String>?) in
        var updated: Array<String> = silenced ?? .init()
        guard !updated.contains(notice.identifier)
        else { return }
        updated.append(notice.identifier)
        silenced = updated
      }
    }

    return Self(
      pendingNotice: pendingNotice,
      markPresented: markPresented(_:),
      silence: silence(_:)
    )
  }
}

extension DeprecationCheck: LoadableFeature {

  #if DEBUG
  nonisolated internal static var placeholder: Self {
    Self(
      pendingNotice: unimplemented0(),
      markPresented: unimplemented1(),
      silence: unimplemented1()
    )
  }
  #endif
}

extension FeaturesRegistry {

  internal mutating func usePassboltDeprecationCheck() {
    self.use(
      .lazyLoaded(
        DeprecationCheck.self,
        load: { try DeprecationCheck.load(features: $0) }
      ),
      in: RootFeaturesScope.self
    )
    self.usePassboltStoredProperty(
      SilencedDeprecationNoticesStoredPropertyDescription.self,
      in: RootFeaturesScope.self
    )
  }
}

internal typealias SilencedDeprecationNoticesStoredProperty = StoredProperty<
  SilencedDeprecationNoticesStoredPropertyDescription
>

internal enum SilencedDeprecationNoticesStoredPropertyDescription: StoredPropertyDescription {

  internal typealias Value = Array<String>

  internal static var shared: Bool { true }
  internal static var key: OSStoredPropertyKey { "silencedDeprecationNotices" }
}
