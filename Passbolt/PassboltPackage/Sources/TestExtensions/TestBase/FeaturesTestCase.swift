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

import CoreTest
import Display
import Features
import XCTest

@MainActor
open class FeaturesTestCase: TestCase {

  public let asyncExecutionControl: AsyncExecutor.MockExecutionControl = .init()
  public var cancellables: Cancellables { self.testFeatures.cancellables }  // for legacy elements

  private let testFeatures: TestFeaturesContainer = .init()

  open func commonPrepare() {
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
    _ featureType: Feature.Type = Feature.self
  ) throws -> Feature
  where Feature: LoadableFeature {
    try self.testFeatures.instance(of: featureType)
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
    for _: Feature.Type
  ) where Feature: LoadableFeature {
    self.testFeatures.usePlaceholder(for: Feature.self)
  }

  public func usePlaceholder<Feature>(
    for featureType: Feature.Type
  ) where Feature: StaticFeature {
    self.testFeatures
      .usePlaceholder(for: Feature.self)
  }

  public final func use<MockFeature>(
    _ instance: MockFeature
  ) where MockFeature: LoadableFeature {
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
    with value: Value
  ) where MockFeature: LoadableFeature {
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

	public func withInstance<Feature>(
		of _: Feature.Type = Feature.self,
		file: StaticString = #file,
		line: UInt = #line,
		test: @escaping @Sendable (Feature) async throws -> Void
	) async
	where Feature: LoadableFeature {
		do {
			try await test(self.testedInstance())
		}
		catch {
			XCTFail(
				"Unexpected error: \(error)",
				file: file,
				line: line
			)
		}
	}

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
      XCTFail(
        "Unexpected error: \(error)",
        file: file,
        line: line
      )
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
      XCTFail(
        "Unexpected error: \(error)",
        file: file,
        line: line
      )
    }
  }

  nonisolated public var mockWasExecuted: Bool {
    @Sendable get {
      self.loadOrDefine(
        \.executedCount,
        of: UInt.self,
        defaultValue: 0
      ) > 0
    }
  }

  nonisolated public var mockExecutedCount: UInt {
    @Sendable get {
      self.loadOrDefine(
        \.executedCount,
        defaultValue: 0
      )
    }
  }

  @Sendable nonisolated public func mockExecuted() {
    let count: UInt = self.loadOrDefine(
      \.executedCount,
      defaultValue: 0
    )
    self.executedCount = count + 1
    self.setOrDefine(\.executedArgument, value: Void())
  }

  @Sendable nonisolated public func mockExecuted<Argument>(
    with argument: Argument
	) {
		let count: UInt = self.loadOrDefine(
			\.executedCount,
			 defaultValue: 0
		)
		self.executedCount = count + 1
		self.setOrDefine(\.executedArgument, value: argument)
	}

	public func withInstance<Feature>(
		of _: Feature.Type = Feature.self,
		mockExecuted: UInt,
		file: StaticString = #file,
		line: UInt = #line,
		test: @escaping @Sendable (Feature) async throws -> Void
	) async
	where Feature: LoadableFeature {
		do {
			try await test(self.testedInstance())
			XCTAssertEqual(
				mockExecuted,
				self.loadOrDefine(
					\.executedCount,
					defaultValue: 0
				),
				"Executed count was not matching expected",
				file: file,
				line: line
			)
		}
		catch {
			XCTFail(
				"Unexpected error: \(error)",
				file: file,
				line: line
			)
		}
	}

	public func withInstance<Feature, Argument>(
		of _: Feature.Type = Feature.self,
		mockExecutedWith: Argument,
		file: StaticString = #file,
		line: UInt = #line,
		test: @escaping @Sendable (Feature) async throws -> Void
	) async
	where Feature: LoadableFeature, Argument: Equatable {
		do {
			try await test(self.testedInstance())
			XCTAssertEqual(
				mockExecutedWith,
				self.loadIfDefined(
					\.executedArgument,
					of: Argument.self
				),
				"Executed argument was invalid or missing",
				file: file,
				line: line
			)
		}
		catch {
			XCTFail(
				"Unexpected error: \(error)",
				file: file,
				line: line
			)
		}
	}

	public func withInstance<Feature, Value>(
		of _: Feature.Type = Feature.self,
		returns: Value,
		file: StaticString = #file,
		line: UInt = #line,
		test: @escaping @Sendable (Feature) async throws -> Value
	) async
	where Feature: LoadableFeature, Value: Equatable {
		do {
			let returned: Value = try await test(self.testedInstance())
			XCTAssertEqual(
				returns,
				returned,
				"Returned value was invalid",
				file: file,
				line: line
			)
		}
		catch {
			XCTFail(
				"Unexpected error: \(error)",
				file: file,
				line: line
			)
		}
	}

	public func withInstance<Feature, Value, Failure>(
		of _: Feature.Type = Feature.self,
		throws: Failure.Type,
		file: StaticString = #file,
		line: UInt = #line,
		test: @escaping @Sendable (Feature) async throws -> Value
	) async
	where Feature: LoadableFeature, Failure: Error {
		do {
			_ = try await test(self.testedInstance())
			XCTFail(
				"Expected error not thrown",
				file: file,
				line: line
			)
		}
		catch is Failure {
			// expected
		}
		catch {
			XCTFail(
				"Unexpected error: \(error)",
				file: file,
				line: line
			)
		}
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
        self.loadOrDefine(
          \.executedCount,
          defaultValue: 0
        ),
        "Executed count was not matching expected",
        file: file,
        line: line
      )
    }
    catch {
      XCTFail(
        "Unexpected error: \(error)",
        file: file,
        line: line
      )
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
        self.loadOrDefine(
          \.executedCount,
          defaultValue: 0
        ),
        "Executed count was not matching expected",
        file: file,
        line: line
      )
    }
    catch {
      XCTFail(
        "Unexpected error: \(error)",
        file: file,
        line: line
      )
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
        self.loadIfDefined(
          \.executedArgument,
          of: Argument.self
        ),
        "Executed argument was invalid or missing",
        file: file,
        line: line
      )
    }
    catch {
      XCTFail(
        "Unexpected error: \(error)",
        file: file,
        line: line
      )
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
        self.loadIfDefined(
          \.executedArgument,
          of: Argument.self
        ),
        "Executed argument was invalid or missing",
        file: file,
        line: line
      )
    }
    catch {
      XCTFail(
        "Unexpected error: \(error)",
        file: file,
        line: line
      )
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
        "Returned value was invalid",
        file: file,
        line: line
      )
    }
    catch {
      XCTFail(
        "Unexpected error: \(error)",
        file: file,
        line: line
      )
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
        "Returned value was invalid",
        file: file,
        line: line
      )
    }
    catch {
      XCTFail(
        "Unexpected error: \(error)",
        file: file,
        line: line
      )
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
      XCTFail(
        "Expected error not thrown",
        file: file,
        line: line
      )
    }
    catch is Failure {
      // expected
    }
    catch {
      XCTFail(
        "Unexpected error: \(error)",
        file: file,
        line: line
      )
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
  where Controller: ViewController, Failure: Error {
    do {
      _ = try await test(self.testedInstance(context: context))
      XCTFail(
        "Expected error not thrown",
        file: file,
        line: line
      )
    }
    catch is Failure {
      // expected
    }
    catch {
      XCTFail(
        "Unexpected error: \(error)",
        file: file,
        line: line
      )
    }
  }
}
