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

import CommonModels
import Foundation

public struct Files: EnvironmentElement {

  public var deleteFile: (URL) -> Result<Void, Error>
  public var contentsOfDirectory: (URL) -> Result<Array<String>, Error>
  public var applicationDataDirectory: () -> Result<URL, Error>
}

extension Files {

  public static var live: Self {
    let fileManager: FileManager = .default

    return Self(
      deleteFile: { fileURL in
        do {
          try fileManager.removeItem(at: fileURL)
          return .success
        }
        catch let nsError as NSError where nsError.code == NSFileNoSuchFileError {
          return .success  // file does not exists
        }
        catch {
          return .failure(
            FileAccessIssue
              .error("Cannot delete local file")
              .recording(fileURL, for: "fileURL")
              .recording(error, for: "underlyingError")
          )
        }
      },
      contentsOfDirectory: { directoryURL in
        do {
          let contents: Array<URL> =
            try fileManager
            .contentsOfDirectory(
              at: directoryURL,
              includingPropertiesForKeys: nil,
              options: .skipsSubdirectoryDescendants
            )
          return .success(
            contents
              .map { url in
                url.lastPathComponent
              }
          )
        }
        catch {
          return .failure(
            DirectoryAccessIssue
              .error("Cannot access directory")
              .recording(directoryURL, for: "directoryURL")
              .recording(error, for: "underlyingError")
          )
        }
      },
      applicationDataDirectory: {
        do {
          let url: URL =
            try fileManager
            .url(
              for: .applicationSupportDirectory,
              in: .userDomainMask,
              appropriateFor: nil,
              create: true
            )
          return .success(url)
        }
        catch {
          return .failure(
            DirectoryAccessIssue
              .error("Cannot access appplication data directory")
              .recording(error, for: "underlyingError")
          )
        }
      }
    )
  }
}

extension AppEnvironment {

  public var files: Files {
    get { element(Files.self) }
    set { use(newValue) }
  }
}

#if DEBUG
extension Files {

  // placeholder implementation for mocking and testing, unavailable in release
  public static var placeholder: Self {
    Self(
      deleteFile: unimplemented("You have to provide mocks for used methods"),
      contentsOfDirectory: unimplemented("You have to provide mocks for used methods"),
      applicationDataDirectory: unimplemented("You have to provide mocks for used methods")
    )
  }
}
#endif
