import Combine
import CommonDataModels
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
                resourceType.slug.rawValue,
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
        for field in resourceType.properties {
          // insert fields for type (previous were deleted, no need for update)
          let result: Result<Int, TheError> =
            conn
            .execute(
              insertFieldStatement,
              with: field.field.rawValue,
              field.type.rawValue,
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

public typealias FetchResourcesTypesOperation = DatabaseOperation<Void, Array<ResourceType>>

extension FetchResourcesTypesOperation {

  static func using(
    _ connectionPublisher: AnyPublisher<SQLiteConnection, TheError>
  ) -> Self {
    withConnection(
      using: connectionPublisher
    ) { conn, _ in
      conn
        .fetch(
          selectTypesStatement
        ) { rows in
          .success(
            rows.compactMap { row -> ResourceType? in
              guard
                let id: ResourceType.ID = (row.id as String?).map(ResourceType.ID.init(rawValue:)),
                let slug: ResourceType.Slug = (row.slug as String?).map(ResourceType.Slug.init(rawValue:)),
                let name: String = row.name,
                let rawFields: String = row.fields
              else { return nil }
              return ResourceType(
                id: id,
                slug: slug,
                name: name,
                fields: ResourceProperty.arrayFrom(rawString: rawFields)
              )
            }
          )
        }
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

// select types
private let selectTypesStatement: SQLiteStatement = """
  SELECT
    id,
    slug,
    name,
    fields
  FROM
    resourceTypesView;
  """

// insert or update type
private let upsertTypeStatement: SQLiteStatement = """
  INSERT INTO
    resourceTypes(
      id,
      slug,
      name
    )
  VALUES
    (
      ?1,
      ?2,
      ?3
    )
  ON CONFLICT
    (
      id
    )
  DO UPDATE SET
    slug=?2,
    name=?3
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

extension ResourceProperty {

  internal static func arrayFrom(
    rawString: String
  ) -> Array<Self> {
    rawString.components(separatedBy: ",").compactMap(from(string:))
  }

  internal static func from(
    string: String
  ) -> Self? {
    var fields = string.components(separatedBy: ";")

    let maxLength: Int? = fields.popLast()?.components(separatedBy: "=").last.flatMap { Int($0) }

    guard
      let encrypted: Bool = fields.popLast()?.components(separatedBy: "=").last.flatMap({ $0 == "1" }),
      let required: Bool = fields.popLast()?.components(separatedBy: "=").last.flatMap({ $0 == "1" }),
      var nameAndTypeString: Array<String> = fields.popLast()?.components(separatedBy: ":"),
      let typeString: String = nameAndTypeString.popLast(),
      let name: String = nameAndTypeString.popLast()
    else { return nil }

    return .init(
      name: name,
      typeString: typeString,
      required: required,
      encrypted: encrypted,
      maxLength: maxLength
    )
  }
}
