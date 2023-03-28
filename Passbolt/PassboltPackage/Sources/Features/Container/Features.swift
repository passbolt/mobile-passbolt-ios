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

public protocol Features {

  func checkScope<Scope>(
    _: Scope.Type,
    file: StaticString,
    line: UInt
  ) -> Bool
  where Scope: FeaturesScope

  func ensureScope<Scope>(
    _: Scope.Type,
    file: StaticString,
    line: UInt
  ) throws where Scope: FeaturesScope

  func context<Scope>(
    of scope: Scope.Type,
    file: StaticString,
    line: UInt
  ) throws -> Scope.Context
  where Scope: FeaturesScope

  @MainActor func branch<Scope>(
    scope: Scope.Type,
    context: Scope.Context,
    file: StaticString,
    line: UInt
  ) -> FeaturesContainer
  where Scope: FeaturesScope

  @MainActor func instance<Feature>(
    of featureType: Feature.Type,
    file: StaticString,
    line: UInt
  ) -> Feature
  where Feature: StaticFeature

  @MainActor func instance<Feature>(
    of featureType: Feature.Type,
    context: Feature.Context,
    file: StaticString,
    line: UInt
  ) throws -> Feature
  where Feature: LoadableFeature
}

extension Features {

  public func checkScope<Scope>(
    _: Scope.Type,
    _ file: StaticString = #fileID,
    _ line: UInt = #line
  ) -> Bool
  where Scope: FeaturesScope {
    self.checkScope(
      Scope.self,
      file: file,
      line: line
    )
  }

  public func ensureScope<Scope>(
    _: Scope.Type,
    _ file: StaticString = #fileID,
    _ line: UInt = #line
  ) throws where Scope: FeaturesScope {
    try self.ensureScope(
      Scope.self,
      file: file,
      line: line
    )
  }

  public func context<Scope>(
    of _: Scope.Type,
    _ file: StaticString = #fileID,
    _ line: UInt = #line
  ) throws -> Scope.Context
  where Scope: FeaturesScope {
    try self.context(
      of: Scope.self,
      file: file,
      line: line
    )
  }

  @MainActor public func branch<Scope>(
    scope: Scope.Type,
    context: Scope.Context,
    _ file: StaticString = #fileID,
    _ line: UInt = #line
  ) -> FeaturesContainer
  where Scope: FeaturesScope {
    self.branch(
      scope: Scope.self,
      context: context,
      file: file,
      line: line
    )
  }

  @MainActor public func branch<Scope>(
    scope: Scope.Type,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> FeaturesContainer
  where Scope: FeaturesScope, Scope.Context == Void {
    self.branch(
      scope: Scope.self,
      context: Void(),
      file: file,
      line: line
    )
  }

  @MainActor public func branchIfNeeded<Scope>(
    scope: Scope.Type,
    context: Scope.Context,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> FeaturesContainer?
  where Scope: FeaturesScope {
    let hasScope: Bool = self.checkScope(
      scope,
      file: file,
      line: line
    )
    guard !hasScope else { return .none }
    return self.branch(
      scope: scope,
      context: context,
      file: file,
      line: line
    )
  }

  @MainActor public func branchIfNeeded<Scope>(
    scope: Scope.Type,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> FeaturesContainer?
  where Scope: FeaturesScope, Scope.Context == Void {
    self.branchIfNeeded(
      scope: Scope.self,
      context: Void(),
      file: file,
      line: line
    )
  }

  @MainActor public func instance<Feature>(
    of featureType: Feature.Type = Feature.self,
    _ file: StaticString = #fileID,
    _ line: UInt = #line
  ) -> Feature
  where Feature: StaticFeature {
    self.instance(
      of: featureType,
      file: file,
      line: line
    )
  }

  @MainActor public func instance<Feature>(
    of featureType: Feature.Type = Feature.self,
    context: Feature.Context,
    _ file: StaticString = #fileID,
    _ line: UInt = #line
  ) throws -> Feature
  where Feature: LoadableFeature {
    try self.instance(
      of: featureType,
      context: context,
      file: file,
      line: line
    )
  }

  @MainActor public func instance<Feature>(
    of featureType: Feature.Type = Feature.self,
    file: StaticString = #fileID,
    line: UInt = #line
  ) throws -> Feature
  where Feature: LoadableFeature, Feature.Context == ContextlessLoadableFeatureContext {
    try self.instance(
      of: featureType,
      context: .instance,
      file: file,
      line: line
    )
  }

  @MainActor public func instance<Feature>(
    of featureType: Feature.Type = Feature.self,
    file: StaticString = #fileID,
    line: UInt = #line
  ) throws -> Feature
  where Feature: LoadableFeature, Feature.Context == Void {
    try self.instance(
      of: featureType,
      context: Void(),
      file: file,
      line: line
    )
  }
}
