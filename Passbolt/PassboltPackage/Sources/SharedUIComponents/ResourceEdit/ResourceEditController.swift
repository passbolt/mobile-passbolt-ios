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

import Accounts
import CommonModels
import Crypto
import OSFeatures
import Resources
import SessionData
import UIComponents

public struct ResourceEditController {

  internal var createsNewResource: Bool
  internal var resourcePropertiesPublisher: @MainActor () -> AnyPublisher<OrderedSet<ResourceFieldSpecification>, Never>
  internal var fieldValuePublisher: @MainActor (Resource.FieldPath) -> AnyPublisher<Validated<String>, Never>
  internal var passwordEntropyPublisher: @MainActor () -> AnyPublisher<Entropy, Never>
  internal var sendForm: @MainActor () -> AnyPublisher<Void, Error>
  internal var setValue: @MainActor (String, ResourceFieldSpecification) -> Void
  internal var generatePassword: @MainActor () -> Void
  internal var presentExitConfirmation: @MainActor () -> Void
  internal var exitConfirmationPresentationPublisher: @MainActor () -> AnyPublisher<Bool, Never>
}

extension ResourceEditController: UIController {

  public typealias Context = (
    editing: ResourceEditScope.Context,
    completion: (Resource.ID) -> Void
  )

  public static func instance(
    in context: Context,
    with features: inout Features,
    cancellables: Cancellables
  ) throws -> Self {
    features = features.branch(
      scope: ResourceEditScope.self,
      context: context.editing
    )
    let diagnostics: OSDiagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = try features.instance()
    let resourceForm: LegacyResourceEditForm = try features.instance()
    let randomGenerator: RandomStringGenerator = try features.instance()

    let createsNewResource: Bool = {
      switch context.editing {
      case .edit:
        return false

      case .create:
        return true
      }
    }()

    let exitConfirmationPresentationSubject: PassthroughSubject<Bool, Never> = .init()

    func resourcePropertiesPublisher() -> AnyPublisher<OrderedSet<ResourceFieldSpecification>, Never> {
      resourceForm.fieldsPublisher()
    }

    func fieldValuePublisher(
      for field: Resource.FieldPath
    ) -> AnyPublisher<Validated<String>, Never> {
      resourceForm
        .validatedFieldValuePublisher(field)
        .map { validatedFieldValue -> Validated<String> in
          Validated<String>(
            value: validatedFieldValue.value.stringValue ?? "",
            error: validatedFieldValue.error
          )
        }
        .eraseToAnyPublisher()
    }

    func setValue(
      _ value: String,
      for field: ResourceFieldSpecification
    ) {
      asyncExecutor.scheduleCatchingWith(
        diagnostics,
        failMessage: "Resource field update failed"
      ) {
        try await resourceForm
          .setFieldValue(.string(value), field.path)
      }
    }

    func passwordEntropyPublisher() -> AnyPublisher<Entropy, Never> {
      resourceForm
        .updates
        .map(resourceForm.resource)
        .map { (resource: Resource) in
          randomGenerator.entropy(
            resource.secret.password.stringValue
              ?? resource.secret.secret.stringValue
              ?? "",
            CharacterSets.all
          )
        }
        .asThrowingPublisher()
        .replaceError(with: .zero)
        .eraseToAnyPublisher()
    }

    func sendForm() -> AnyPublisher<Void, Error> {
      cancellables.executeAsyncWithPublisher { () async throws -> Void in
        let resourceID: Resource.ID = try await resourceForm.sendForm()
        context.completion(resourceID)
      }
      .collectErrorLog(using: diagnostics)
      .eraseToAnyPublisher()
    }

    func generatePassword() {
      asyncExecutor.scheduleCatchingWith(
        diagnostics,
        failMessage: "Password generation failed",
        behavior: .reuse
      ) {
        let passwordField: ResourceFieldSpecification?
        if let field = try await resourceForm.resource().type.specification.fieldSpecification(for: \.secret.password) {
          passwordField = field
        }
        else if let field = try await resourceForm.resource().type.specification.fieldSpecification(for: \.secret) {
          passwordField = field
        }
        else {
          passwordField = .none
        }

        guard let passwordField: ResourceFieldSpecification
        else { return assertionFailure("Trying to generate password without pasword field") }

        let password: String = randomGenerator.generate(
          CharacterSets.all,
          18,
          Entropy.veryStrongPassword
        )

        try await resourceForm
          .setFieldValue(.string(password), passwordField.path)
      }

    }

    func presentExitConfirmation() {
      exitConfirmationPresentationSubject.send(true)
    }

    func exitConfirmationPresentationPublisher() -> AnyPublisher<Bool, Never> {
      exitConfirmationPresentationSubject.eraseToAnyPublisher()
    }

    return Self(
      createsNewResource: createsNewResource,
      resourcePropertiesPublisher: resourcePropertiesPublisher,
      fieldValuePublisher: fieldValuePublisher(for:),
      passwordEntropyPublisher: passwordEntropyPublisher,
      sendForm: sendForm,
      setValue: setValue(_:for:),
      generatePassword: generatePassword,
      presentExitConfirmation: presentExitConfirmation,
      exitConfirmationPresentationPublisher: exitConfirmationPresentationPublisher
    )
  }
}
