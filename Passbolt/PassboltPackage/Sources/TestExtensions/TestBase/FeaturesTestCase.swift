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

import Display
import Features
import XCTest

@MainActor
open class FeaturesTestCase: XCTestCase {

  public let asyncExecutionControl: AsyncExecutor.MockExecutionControl = .init()
  public nonisolated let dynamicVariables: DynamicVariables = .init()
  public var cancellables: Cancellables { self.testFeatures.cancellables }  // for legacy elements

  private let testFeatures: TestFeaturesContainer = .init()

  open func commonPrepare() {
    patch(
      \OSDiagnostics.self,
      with: .disabled
    )
    patch(
      \AsyncExecutor.self,
      with: .mock(self.asyncExecutionControl)
    )
  }

  final override public class func setUp() {
    super.setUp()
  }

  public final override func setUp() {
    /* NOP - overrding to ignore calls from default setUp methods calling order */
  }

  public final override func setUp() async throws {
    // casting to specify correct method to be called,
    // by default async one is selected by the compiler
    (super.setUp as () -> Void)()
    try await super.setUp()
    self.commonPrepare()
  }

  public final override func tearDown() {
    /* NOP - overrding to ignore calls from default tearDown methods calling order */
  }

  public final override func tearDown() async throws {
    try await super.tearDown()
    // casting to specify correct method to be called,
    // by default async one is selected by the compiler
    (super.tearDown as () -> Void)()
    XCTAssertEqual(
      self.asyncExecutionControl.scheduledTasksCount,
      0,
      "All scheduled async tasks should be finished."
    )
  }
}

extension FeaturesTestCase {

  public final func testedInstance<Feature>(
    _ featureType: Feature.Type = Feature.self,
    context: Feature.Context
  ) throws -> Feature
  where Feature: LoadableFeature {
    try self.testFeatures
      .instance(
        of: featureType,
        context: context
      )
  }

  public final func testedInstance<Feature>(
    _ featureType: Feature.Type = Feature.self
  ) throws -> Feature
  where Feature: LoadableFeature, Feature.Context == Void {
    try self.testFeatures
      .instance(
        of: featureType
      )
  }

  public final func testedInstance<Feature>(
    _ featureType: Feature.Type = Feature.self
  ) throws -> Feature
  where Feature: LoadableFeature, Feature.Context == ContextlessLoadableFeatureContext {
    try self.testFeatures
      .instance(
        of: featureType
      )
  }

  public final func testedInstance<Alert>(
    _ alertType: Alert.Type = Alert.self,
    context: Alert.Context
  ) throws -> Alert
  where Alert: AlertController {
    try Alert(
      with: context,
      using: self.testFeatures
    )
  }

  public final func testedInstance<Alert>(
    _ alertType: Alert.Type = Alert.self
  ) throws -> Alert
  where Alert: AlertController, Alert.Context == Void {
    try Alert(
      with: Void(),
      using: self.testFeatures
    )
  }

	public final func testedInstance<Controller>(
		_ featureType: Controller.Type = Controller.self,
		context: Controller.Context
	) throws -> Controller
	where Controller: ViewController {
		try Controller(
			context: context,
			features: self.testFeatures
		)
	}

	public final func testedInstance<Controller>(
		_ featureType: Controller.Type = Controller.self
	) throws -> Controller
	where Controller: ViewController, Controller.Context == Void {
		try Controller(
			context: Void(),
			features: self.testFeatures
		)
	}
}

// Legacy support
extension FeaturesTestCase {

  public final func testedInstance<Controller>(
    _ featureType: Controller.Type = Controller.self,
    context: Controller.Context
  ) throws -> Controller
  where Controller: UIController {
    var features: Features = self.testFeatures
    let instance: Controller = try .instance(
      in: context,
      with: &features,
      cancellables: self.cancellables
    )
    guard features as? FeaturesContainer === self.testFeatures
    else { unreachable("Test container can't be changed") }
    return instance
  }

  public final func testedInstance<Controller>(
    _ featureType: Controller.Type = Controller.self
  ) throws -> Controller
  where Controller: UIController, Controller.Context == Void {
    var features: Features = self.testFeatures
    let instance: Controller = try .instance(
      in: Void(),
      with: &features,
      cancellables: self.cancellables
    )
    guard features as? FeaturesContainer === self.testFeatures
    else { unreachable("Test container can't be changed") }
    return instance
  }
}

extension FeaturesTestCase {

  public func set<Scope>(
    _ scope: Scope.Type,
    context: Scope.Context
  ) where Scope: FeaturesScope {
    self.testFeatures
      .set(
        scope,
        context: context
      )
  }

  public func set<Scope>(
    _ scope: Scope.Type
  ) where Scope: FeaturesScope, Scope.Context == Void {
    self.testFeatures
      .set(scope)
  }

  public func register<Feature>(
    _ register: (inout FeaturesRegistry) -> Void,
    for _: Feature.Type
  ) where Feature: LoadableFeature {
    self.testFeatures
      .register(
        register,
        for: Feature.self
      )
  }

  public func usePlaceholder<Feature>(
    for _: Feature.Type,
    context: Feature.Context
  ) where Feature: LoadableFeature {
    self.testFeatures
      .usePlaceholder(
        for: Feature.self,
        context: context
      )
  }

  public func usePlaceholder<Feature>(
    for featureType: Feature.Type
  ) where Feature: LoadableFeature, Feature.Context == Void {
    self.testFeatures
      .usePlaceholder(for: Feature.self)
  }

  public func usePlaceholder<Feature>(
    for featureType: Feature.Type
  ) where Feature: StaticFeature {
    self.testFeatures
      .usePlaceholder(for: Feature.self)
  }

  public final func use<MockFeature>(
    _ instance: MockFeature,
    context: MockFeature.Context
  ) where MockFeature: LoadableFeature {
    self.testFeatures
      .patch(
        \MockFeature.self,
        context: context,
        with: instance
      )
  }

  public final func use<MockFeature>(
    _ instance: MockFeature
  ) where MockFeature: LoadableFeature, MockFeature.Context == Void {
    self.testFeatures
      .patch(
        \MockFeature.self,
        with: instance
      )
  }

  public final func use<MockFeature>(
    _ instance: MockFeature
  ) where MockFeature: StaticFeature {
    self.testFeatures
      .patch(
        \MockFeature.self,
        with: instance
      )
  }

  public func patch<MockFeature, Value>(
    _ keyPath: WritableKeyPath<MockFeature, Value>,
    context: MockFeature.Context,
    with value: Value
  ) where MockFeature: LoadableFeature {
    self.testFeatures
      .patch(
        keyPath,
        context: context,
        with: value
      )
  }

  public func patch<MockFeature, Value>(
    _ keyPath: WritableKeyPath<MockFeature, Value>,
    with value: Value
  ) where MockFeature: LoadableFeature, MockFeature.Context == ContextlessLoadableFeatureContext {
    self.testFeatures
      .patch(
        keyPath,
        context: ContextlessLoadableFeatureContext.instance,
        with: value
      )
  }

  public func patch<MockFeature, Value>(
    _ keyPath: WritableKeyPath<MockFeature, Value>,
    with value: Value
  ) where MockFeature: LoadableFeature, MockFeature.Context == Void {
    self.testFeatures
      .patch(
        keyPath,
        with: value
      )
  }

  public func patch<MockFeature, Value>(
    _ keyPath: WritableKeyPath<MockFeature, Value>,
    with value: Value
  ) where MockFeature: StaticFeature {
    self.testFeatures
      .patch(
        keyPath,
        with: value
      )
  }
}

extension FeaturesTestCase {

	public func withInstance<Controller>(
		of _: Controller.Type = Controller.self,
		file: StaticString = #file,
		line: UInt = #line,
		test: @escaping @Sendable (Controller) async throws -> Void
	) async
	where Controller: ViewController, Controller.Context == Void {
		do {
			try await test(self.testedInstance())
		}
		catch {
			XCTFail("Unexpected error: \(error)")
		}
	}

	public func withInstance<Controller>(
		of _: Controller.Type = Controller.self,
		context: Controller.Context,
		file: StaticString = #file,
		line: UInt = #line,
		test: @escaping @Sendable (Controller) async throws -> Void
	) async
	where Controller: ViewController {
		do {
			try await test(self.testedInstance(context: context))
		}
		catch {
			XCTFail("Unexpected error: \(error)")
		}
	}

	@Sendable nonisolated public func mockExecuted() {
		if let count: UInt = self.dynamicVariables.getIfPresent(\.executed, of: UInt.self) {
			self.dynamicVariables.set(\.mockExecuted, of: UInt.self, to: count + 1)
		}
		else {
			self.dynamicVariables.set(\.mockExecuted, of: UInt.self, to: 1)
		}
		self.dynamicVariables.set(\.mockExecutedArgument, to: Void())
	}

	@Sendable nonisolated public func mockExecuted<Argument>(
		with argument: Argument
	) {
		if let count: UInt = self.dynamicVariables.getIfPresent(\.executed, of: UInt.self) {
			self.dynamicVariables.set(\.mockExecuted, of: UInt.self, to: count + 1)
		}
		else {
			self.dynamicVariables.set(\.mockExecuted, of: UInt.self, to: 1)
		}
		self.dynamicVariables.set(\.mockExecutedArgument, to: argument)
	}

	public func withInstance<Controller>(
		of _: Controller.Type = Controller.self,
		mockExecuted: UInt,
		file: StaticString = #file,
		line: UInt = #line,
		test: @escaping @Sendable (Controller) async throws -> Void
	) async
	where Controller: ViewController, Controller.Context == Void {
		do {
			try await test(self.testedInstance())
			XCTAssertEqual(
				mockExecuted,
				self.dynamicVariables.getIfPresent(\.mockExecuted, of: UInt.self) ?? 0,
				"Executed count was not matching expected"
			)
		}
		catch {
			XCTFail("Unexpected error: \(error)")
		}
	}

	public func withInstance<Controller>(
		of _: Controller.Type = Controller.self,
		context: Controller.Context,
		mockExecuted: UInt,
		file: StaticString = #file,
		line: UInt = #line,
		test: @escaping @Sendable (Controller) async throws -> Void
	) async
	where Controller: ViewController {
		do {
			try await test(self.testedInstance(context: context))
			XCTAssertEqual(
				mockExecuted,
				self.dynamicVariables.getIfPresent(\.mockExecuted, of: UInt.self) ?? 0,
				"Executed count was not matching expected"
			)
		}
		catch {
			XCTFail("Unexpected error: \(error)")
		}
	}

	public func withInstance<Controller, Argument>(
		of _: Controller.Type = Controller.self,
		mockExecutedWith: Argument,
		file: StaticString = #file,
		line: UInt = #line,
		test: @escaping @Sendable (Controller) async throws -> Void
	) async
	where Controller: ViewController, Controller.Context == Void, Argument: Equatable {
		do {
			try await test(self.testedInstance())
			XCTAssertEqual(
				mockExecutedWith,
				self.dynamicVariables.getIfPresent(\.mockExecutedArgument, of: Argument.self),
				"Executed argument was invalid or missing"
			)
		}
		catch {
			XCTFail("Unexpected error: \(error)")
		}
	}

	public func withInstance<Controller, Argument>(
		of _: Controller.Type = Controller.self,
		context: Controller.Context,
		mockExecutedWith: Argument,
		file: StaticString = #file,
		line: UInt = #line,
		test: @escaping @Sendable (Controller) async throws -> Void
	) async
	where Controller: ViewController, Argument: Equatable {
		do {
			try await test(self.testedInstance(context: context))
			XCTAssertEqual(
				mockExecutedWith,
				self.dynamicVariables.getIfPresent(\.mockExecutedArgument, of: Argument.self),
				"Executed argument was invalid or missing"
			)
		}
		catch {
			XCTFail("Unexpected error: \(error)")
		}
	}

	public func withInstance<Controller, Value>(
		of _: Controller.Type = Controller.self,
		returns: Value,
		file: StaticString = #file,
		line: UInt = #line,
		test: @escaping @Sendable (Controller) async throws -> Value
	) async
	where Controller: ViewController, Controller.Context == Void, Value: Equatable {
		do {
			let returned: Value = try await test(self.testedInstance())
			XCTAssertEqual(
				returns,
				returned,
				"Returned value was invalid"
			)
		}
		catch {
			XCTFail("Unexpected error: \(error)")
		}
	}

	public func withInstance<Controller, Value>(
		of _: Controller.Type = Controller.self,
		context: Controller.Context,
		returns: Value,
		file: StaticString = #file,
		line: UInt = #line,
		test: @escaping @Sendable (Controller) async throws -> Value
	) async
	where Controller: ViewController, Value: Equatable {
		do {
			let returned: Value = try await test(self.testedInstance(context: context))
			XCTAssertEqual(
				returns,
				returned,
				"Returned value was invalid"
			)
		}
		catch {
			XCTFail("Unexpected error: \(error)")
		}
	}

	public func withInstance<Controller, Value, Failure>(
		of _: Controller.Type = Controller.self,
		throws: Failure.Type,
		file: StaticString = #file,
		line: UInt = #line,
		test: @escaping @Sendable (Controller) async throws -> Value
	) async
	where Controller: ViewController, Controller.Context == Void, Failure: Error {
		do {
			_ = try await test(self.testedInstance())
			XCTFail("Expected error not thrown")
		}
		catch is Failure {
			// expected
		}
		catch {
			XCTFail("Unexpected error: \(error)")
		}
	}

	public func withInstance<Controller, Value, Failure>(
		of _: Controller.Type = Controller.self,
		context: Controller.Context,
		throws: Failure.Type,
		file: StaticString = #file,
		line: UInt = #line,
		test: @escaping @Sendable (Controller) async throws -> Value
	) async
	where Controller: ViewController, Controller.Context == Void, Failure: Error {
		do {
			_ = try await test(self.testedInstance(context: context))
			XCTFail("Expected error not thrown")
		}
		catch is Failure {
			// expected
		}
		catch {
			XCTFail("Unexpected error: \(error)")
		}
	}
}
