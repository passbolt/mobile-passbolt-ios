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

import struct Foundation.FileAttributeKey
import class Foundation.FileManager
import struct Foundation.FileProtectionType
import class Foundation.NSError
import let Foundation.NSFileNoSuchFileError
import struct Foundation.URL
import struct Foundation.URLResourceValues

// MARK: - Interface

public struct OSFiles: Sendable {

  public var deleteFile: @Sendable (URL) throws -> Void
  /// Marks a file as excluded from device backups and sets its data protection class.
  /// Does nothing when the file does not exist.
  public var protectFile: @Sendable (URL) throws -> Void
  public var contentsOfDirectory: @Sendable (URL) throws -> Array<String>
  public var applicationDataDirectory: @Sendable () throws -> URL
}

extension OSFiles: StaticFeature {

  #if DEBUG
  nonisolated public static var placeholder: Self {
    Self(
      deleteFile: unimplemented1(),
      protectFile: unimplemented1(),
      contentsOfDirectory: unimplemented1(),
      applicationDataDirectory: unimplemented0()
    )
  }
  #endif
}

// MARK: - Implementation

extension OSFiles {

  fileprivate static var live: Self {
    @Sendable func currentFileManager() -> FileManager { .default }

    @Sendable func deleteFile(
      at fileURL: URL
    ) throws {
      do {
        try currentFileManager().removeItem(at: fileURL)
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

    /// Keeps the file out of iCloud/Finder backups and raises its data protection class so it
    /// stays unreadable while the device is locked. `completeUnlessOpen` is used rather than
    /// `complete` because SQLite keeps the database and its WAL sidecars open across locking.
    @Sendable func protectFile(
      at fileURL: URL
    ) throws {
      guard currentFileManager().fileExists(atPath: fileURL.path)
      else { return }
      do {
        try currentFileManager()
          .setAttributes(
            [FileAttributeKey.protectionKey: FileProtectionType.completeUnlessOpen],
            ofItemAtPath: fileURL.path
          )
        var fileURL: URL = fileURL
        var resourceValues: URLResourceValues = .init()
        resourceValues.isExcludedFromBackup = true
        try fileURL.setResourceValues(resourceValues)
      }
      catch {
        throw
          FileAccessIssue
          .error("Cannot protect local file")
          .recording(fileURL, for: "fileURL")
          .recording(error, for: "underlyingError")
      }
    }

    @Sendable func contentsOfDirectory(
      _ directoryURL: URL
    ) throws -> Array<String> {
      do {
        let contents: Array<URL> =
          try currentFileManager()
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

    @Sendable func applicationDataDirectory() throws -> URL {
      do {
        let url: URL =
          try currentFileManager()
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
      protectFile: protectFile(at:),
      contentsOfDirectory: contentsOfDirectory(_:),
      applicationDataDirectory: applicationDataDirectory
    )
  }
}

extension FeaturesRegistry {

  internal mutating func useOSFiles() {
    self.use(
      OSFiles.live
    )
  }
}
