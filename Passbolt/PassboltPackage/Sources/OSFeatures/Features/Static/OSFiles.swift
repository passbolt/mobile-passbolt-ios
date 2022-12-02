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

import Features

import class Foundation.FileManager
import class Foundation.NSError
import let Foundation.NSFileNoSuchFileError
import struct Foundation.URL

// MARK: - Interface

public struct OSFiles {

  public var deleteFile: (URL) throws -> Void
  public var contentsOfDirectory: (URL) throws -> Array<String>
  public var applicationDataDirectory: () throws -> URL
}

extension OSFiles: StaticFeature {

  #if DEBUG
  nonisolated public static var placeholder: Self {
    Self(
      deleteFile: unimplemented(),
      contentsOfDirectory: unimplemented(),
      applicationDataDirectory: unimplemented()
    )
  }
  #endif
}

// MARK: - Implementation

extension OSFiles {

  fileprivate static var live: Self {
    let fileManager: FileManager = .default

    func deleteFile(
      at fileURL: URL
    ) throws {
      do {
        try fileManager.removeItem(at: fileURL)
      }
      catch let nsError as NSError where nsError.code == NSFileNoSuchFileError {
        // file does not exists
      }
      catch {
        throw
          FileAccessIssue
          .error("Cannot delete local file")
          .recording(fileURL, for: "fileURL")
          .recording(error, for: "underlyingError")
      }
    }

    func contentsOfDirectory(
      _ directoryURL: URL
    ) throws -> Array<String> {
      do {
        let contents: Array<URL> =
          try fileManager
          .contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: .skipsSubdirectoryDescendants
          )
        return
          contents
          .map { url in
            url.lastPathComponent
          }
      }
      catch {
        throw
          DirectoryAccessIssue
          .error("Cannot access directory")
          .recording(directoryURL, for: "directoryURL")
          .recording(error, for: "underlyingError")
      }
    }

    func applicationDataDirectory() throws -> URL {
      do {
        let url: URL =
          try fileManager
          .url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
          )
        return url
      }
      catch {
        throw
          DirectoryAccessIssue
          .error("Cannot access appplication data directory")
          .recording(error, for: "underlyingError")
      }
    }

    return Self(
      deleteFile: deleteFile(at:),
      contentsOfDirectory: contentsOfDirectory(_:),
      applicationDataDirectory: applicationDataDirectory
    )
  }
}

extension FeatureFactory {

  internal func useOSFiles() {
    self.use(
      OSFiles.live
    )
  }
}
