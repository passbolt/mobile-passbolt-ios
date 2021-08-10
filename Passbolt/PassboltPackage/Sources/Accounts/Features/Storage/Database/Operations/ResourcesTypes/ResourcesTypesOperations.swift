import Combine
import Commons
import Environment

public typealias StoreResourcesTypesOperation = DatabaseOperation<Array<ResourceType>, Void>

extension StoreResourcesTypesOperation {

  static func using(
    _ connectionPublisher: AnyPublisher<SQLiteConnection, TheError>
  ) -> Self {
    withConnection(
      using: connectionPublisher
    ) { conn, input in
      // iterate over resources types to insert or update
      for resourceType in input {
        // cleanup existing types as preparation for update
        let result: Result<Void, TheError> =
          conn
          .execute(
            cleanFieldsStatement,
            with: resourceType.id.rawValue
          )
          .flatMap {
            conn
              .execute(
                upsertTypeStatement,
                with: resourceType.id.rawValue,
                resourceType.name
              )
          }

        switch result {
        case .success:
          break

        case let .failure(error):
          return .failure(error)
        }

        // iterate over fields for given resource type
        for field in resourceType.fields {
          // insert fields for type (previous were deleted, no need for update)
          let result: Result<Int, TheError> =
            conn
            .execute(
              insertFieldStatement,
              with: field.name,
              field.typeString,
              field.required,
              field.encrypted,
              field.maxLength
            )
            .flatMap {
              conn
                .fetch(
                  fetchLastInsertedFieldStatement
                ) { rows in
                  if let id: Int = rows.first?.id {
                    return .success(id)
                  }
                  else {
                    return .failure(
                      .databaseExecutionError(
                        databaseErrorMessage: "Failed to insert resource type field"
                      )
                    )
                  }
                }
            }

          switch result {
          case let .success(fieldID):
            // insert association between type and newly added field
            let result: Result<Void, TheError> =
              conn
              .execute(
                insertTypeFieldStatement,
                with: resourceType.id.rawValue,
                fieldID
              )

            switch result {
            case .success:
              continue

            case let .failure(error):
              return .failure(error)
            }

          case let .failure(error):
            return .failure(error)
          }
        }
      }

      // if nothing failed we have succeeded
      return .success
    }
  }
}

// remove all existing fields for given type
private let cleanFieldsStatement: SQLiteStatement = """
  DELETE FROM
    resourceFields
  WHERE
    id
  IN
    (
      SELECT
        resourceFieldID
      FROM
        resourceTypesFields
      WHERE
        resourceTypeID=?1
    )
  ;

  DELETE FROM
    resourceTypesFields
  WHERE
    resourceTypeID=?1
  ;
  """

// insert or update type
private let upsertTypeStatement: SQLiteStatement = """
  INSERT INTO
    resourceTypes(
      id,
      name
    )
  VALUES
    (
      ?1,
      ?2
    )
  ON CONFLICT
    (
      id
    )
  DO UPDATE SET
    name=?2
  ;
  """

// insert single field
private let insertFieldStatement: SQLiteStatement = """
  INSERT INTO
    resourceFields(
      name,
      type,
      required,
      encrypted,
      maxLength
    )
  VALUES
    (
      ?1,
      ?2,
      ?3,
      ?4,
      ?5
    )
  ;
  """

// select last inserted field id
// RETURNING syntax is available from SQLite 3.35
private let fetchLastInsertedFieldStatement: SQLiteStatement = """
  SELECT
    MAX(id) as id
  FROM
    resourceFields
  ;
  """

// insert association between type and field
private let insertTypeFieldStatement: SQLiteStatement = """
  INSERT INTO
    resourceTypesFields(
      resourceTypeID,
      resourceFieldID
    )
  VALUES
    (
      ?1,
      ?2
    )
  ;
  """
