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

internal struct FeaturesProxy {

  internal private(set) weak var container: FeaturesContainer?

  internal init<Scope>(
    container: FeaturesFactory<Scope>
  ) where Scope: FeaturesScope {
    self.container = container
  }
}

extension FeaturesProxy: Features {

  public func checkScope<RequestedScope>(
    _: RequestedScope.Type,
    file: StaticString,
    line: UInt
  ) -> Bool
  where RequestedScope: FeaturesScope {
    if let container: Features = self.container {
      return
        container
        .checkScope(
          RequestedScope.self,
          file: file,
          line: line
        )
    }
    else {
      return false
    }
  }

  public func ensureScope<RequestedScope>(
    _: RequestedScope.Type,
    file: StaticString,
    line: UInt
  ) throws where RequestedScope: FeaturesScope {
    if let container: Features = self.container {
      try container
        .ensureScope(
          RequestedScope.self,
          file: file,
          line: line
        )
    }
    else {
      throw
        InternalInconsistency
        .error(
          "Memory issue - attempting to use a deallocated features container.",
          file: file,
          line: line
        )
    }
  }

  public func context<RequestedScope>(
    of scope: RequestedScope.Type,
    file: StaticString,
    line: UInt
  ) throws -> RequestedScope.Context
  where RequestedScope: FeaturesScope {
    if let container: Features = self.container {
      return
        try container
        .context(
          of: RequestedScope.self,
          file: file,
          line: line
        )
    }
    else {
      throw
        InternalInconsistency
        .error(
          "Memory issue - attempting to use a deallocated features container.",
          file: file,
          line: line
        )
    }
  }

  @MainActor public func branch<RequestedScope>(
    scope: RequestedScope.Type,
    context: RequestedScope.Context,
    file: StaticString,
    line: UInt
  ) throws -> FeaturesContainer
  where RequestedScope: FeaturesScope {
    if let container: Features = self.container {
      return try container
        .branch(
          scope: RequestedScope.self,
          context: context,
          file: file,
          line: line
        )
    }
    else {
      InternalInconsistency
        .error(
          "Memory issue - attempting to use a deallocated features container.",
          file: file,
          line: line
        )
        .asFatalError()
    }
  }

  @MainActor public func takeOwned(
    file: StaticString,
    line: UInt
  ) -> FeaturesContainer {
    if let container: FeaturesContainer = self.container {
      return container
    }
    else {
      InternalInconsistency
        .error(
          "Memory issue - attempting to use a deallocated features container.",
          file: file,
          line: line
        )
        .asFatalError()
    }
  }

  @MainActor public func instance<Feature>(
    of featureType: Feature.Type,
    file: StaticString,
    line: UInt
  ) -> Feature
  where Feature: StaticFeature {
    if let container: Features = self.container {
      return
        container
        .instance(
          of: Feature.self,
          file: file,
          line: line
        )
    }
    else {
      InternalInconsistency
        .error(
          "Memory issue - attempting to use a deallocated features container.",
          file: file,
          line: line
        )
        .asFatalError()
    }
  }

  @MainActor public func instance<Feature>(
    of featureType: Feature.Type,
    file: StaticString,
    line: UInt
  ) throws -> Feature
  where Feature: LoadableFeature {
    if let container: Features = self.container {
      return
        try container
        .instance(
          of: Feature.self,
          file: file,
          line: line
        )
    }
    else {
      throw
        InternalInconsistency
        .error(
          "Memory issue - attempting to use a deallocated features container.",
          file: file,
          line: line
        )
    }
  }
}
