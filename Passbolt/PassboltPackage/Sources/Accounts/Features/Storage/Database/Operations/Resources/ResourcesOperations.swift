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

import Combine
import Commons
import Environment

public typealias StoreResourcesOperation = DatabaseOperation<Array<Resource>, Void>

extension StoreResourcesOperation {

  static func using(
    _ connectionPublisher: AnyPublisher<SQLiteConnection, TheError>
  ) -> Self {
    withConnection(
      using: connectionPublisher
    ) { conn, input in
      for resource in input {
        let result: Result<Void, TheError> =
          conn
          .execute(
            upsertResourceStatement,
            with: resource.id.rawValue,
            resource.name,
            resource.permission.rawValue,
            resource.url,
            resource.username,
            resource.typeID.rawValue,
            resource.description,
            nil  // folders are not implemented yet
          )

        switch result {
        case .success:
          continue

        case let .failure(error):
          return .failure(error)
        }
      }
      return .success
    }
  }
}

public typealias FetchListViewResourcesOperation = DatabaseOperation<ResourcesFilter, Array<ListViewResource>>

extension FetchListViewResourcesOperation {

  static func using(
    _ connectionPublisher: AnyPublisher<SQLiteConnection, TheError>
  ) -> Self {
    withConnection(
      using: connectionPublisher
    ) { conn, input in
      var statement: SQLiteStatement = """
        SELECT
          *
        FROM
          resourcesListView
        WHERE
          1 -- equivalent of true, used to simplify dynamic query building
        """

      var params: Array<SQLiteBindable?> = .init()

      if let textFilter: String = input.text {
        statement.append("\nAND (name LIKE '%' || ? || '%' OR url LIKE '%' || ? || '%')")
        // adding twice since we can't count args when using dynamic query
        // adn argument has to be used twice
        params.append(textFilter)
        params.append(textFilter)
      }
      else {
        /* NOP */
      }

      if let nameFilter: String = input.name {
        statement.append("\nAND name LIKE '%' || ? || '%'")
        params.append(nameFilter)
      }
      else {
        /* NOP */
      }

      if let urlFilter: String =
        input.url
      {
        statement.append("\nAND url LIKE '%' || ? || '%'")
        params.append(urlFilter)
      }
      else {
        /* NOP */
      }

      // end query
      statement.append(";")

      return
        conn
        .fetch(
          statement,
          with: params
        ) { rows in
          .success(
            rows.compactMap { row -> ListViewResource? in
              guard
                let id: ListViewResource.ID = (row.id as String?).map(ListViewResource.ID.init(rawValue:)),
                let permission: ResourcePermission = (row.permission as String?).flatMap(
                  ResourcePermission.init(rawValue:)
                ),
                let name: String = row.name
              else { return nil }
              return ListViewResource(
                id: id,
                permission: permission,
                name: name,
                url: row.url,
                username: row.username
              )
            }
          )
        }
    }
  }
}

public typealias FetchDetailsViewResourcesOperation = DatabaseOperation<Resource.ID, DetailsViewResource>

extension FetchDetailsViewResourcesOperation {

  #warning("TODO: complete in [PAS-186]")
  static func using(
    _ connectionPublisher: AnyPublisher<SQLiteConnection, TheError>
  ) -> Self {
    withConnection(
      using: connectionPublisher
    ) { conn, input in
      fatalError("Not implemented yet")
    }
  }
}

let upsertResourceStatement: SQLiteStatement = """
  INSERT INTO
    resources(
      id,
      name,
      permission,
      url,
      username,
      resourceTypeID,
      description,
      parentFolderID
    )
  VALUES
    (
      ?1,
      ?2,
      ?3,
      ?4,
      ?5,
      ?6,
      ?7,
      ?8
    )
  ON CONFLICT
    (
      id
    )
  DO UPDATE SET
    name=?2,
    permission=?3,
    url=?4,
    username=?5,
    resourceTypeID=?6,
    description=?7,
    parentFolderID=?8
  ;
  """
