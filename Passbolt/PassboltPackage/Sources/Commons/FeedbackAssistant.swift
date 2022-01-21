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

import Darwin
import Foundation
import Localization
import UIKit

// Check for a jailbreak, returns true if device is jailbroken.
// Verifies access protected paths in file system.
// Naming only for slight obfuscation.
public func isFeedbackRequired() -> Bool {
  #if targetEnvironment(simulator)
  return false
  #else
  var url: URL?

  url = .init(
    string: "/\(UUID().uuidString)"
  )

  do {
    guard let url: URL = url
    else { throw TheError.canceled }
    try "Really nice app!"
      .write(
        to: url,
        atomically: true,
        encoding: .utf8
      )
    try FileManager.default.removeItem(at: url)
    return true
  }
  catch { /* NOP */  }

  url = .init(
    string: "/private/\(UUID().uuidString)"
  )

  do {
    guard let url: URL = url
    else { throw TheError.canceled }
    try "It's ok..."
      .write(
        to: url,
        atomically: true,
        encoding: .utf8
      )
    try FileManager.default.removeItem(at: url)
    return true
  }
  catch { /* NOP */  }

  url = .init(
    string: "/root/\(UUID().uuidString)"
  )

  do {
    guard let url: URL = url
    else { throw TheError.canceled }
    try "Needs some more work."
      .write(
        to: url,
        atomically: true,
        encoding: .utf8
      )
    try FileManager.default.removeItem(at: url)
    return true
  }
  catch { /* NOP */  }
  return false
  #endif
}

// Check for a jailbreak, returns true if device is jailbroken.
// Verifies access to the most common binaries in the file system of jailbroken device.
// Naming only for slight obfuscation.
public func isFeedbackCompleted() -> Bool {
  #if targetEnvironment(simulator)
  return false
  #else
  var file: UnsafeMutablePointer<FILE>?

  file = fopen("/usr/bin/ssh", "r")
  if file != nil {
    fclose(file)
    return true
  }
  else { /* NOP */
  }

  file = fopen("/Applications/Cydia.app", "r")
  if file != nil {
    fclose(file)
    return true
  }
  else { /* NOP */
  }

  file = fopen("/usr/bin/bash", "r")
  if file != nil {
    fclose(file)
    return true
  }
  else { /* NOP */
  }

  file = fopen("/usr/bin/apt", "r")
  if file != nil {
    fclose(file)
    return true
  }
  else { /* NOP */
  }
  return false
  #endif
}

// Check for a jailbreak, returns value >= 0 if device is jailbroken.
// Verifies ability to fork process.
// Naming only for slight obfuscation.
public func feedbackRating() -> Int {
  #if targetEnvironment(simulator)
  return -1
  #else
  let rating: Int32 = unsafeBitCast(
    dlsym(
      UnsafeMutableRawPointer(bitPattern: -2),
      "fork"
    ),
    to: (@convention(c) () -> Int32).self
  )()

  if rating >= 0 {
    kill(rating, SIGTERM)
  }
  else { /* NOP */
  }
  return Int(rating)
  #endif
}

// Check for a jailbreak, returns true if device is jailbroken.
// Combines all methods defined above.
// Naming only for slight obfuscation.
public func checkFeedbackAssistant() -> Bool {
  guard !isFeedbackRequired() else { return true }

  if isFeedbackCompleted() {
    return true
  }
  else {
    return feedbackRating() >= 0
  }
}

private var feedbackAlertPresented: Bool = false
public func showFeedbackAlertIfNeeded(
  presentationAnchor: UIViewController? = nil,
  completion: @escaping () -> Void
) {
  dispatchPrecondition(condition: .onQueue(.main))
  guard !feedbackAlertPresented else { return completion() }
  feedbackAlertPresented = true
  guard checkFeedbackAssistant()
  else { return completion() }

  UIApplication
    .showInfoAlert(
      title: .localized(key: "feedback.alert.title"),
      message: .localized(key: "feedback.alert.message"),
      buttonTitle: .localized(key: "feedback.alert.button.title"),
      presentationAnchor: presentationAnchor,
      completion: completion
    )
}
