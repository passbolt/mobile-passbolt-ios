import Commons

public struct UnknownResourceField: TheError {

  public static func error(
    _ message: StaticString,
    path: Resource.FieldPath,
    value: JSON,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    Self(
      context:
        .context(
          .message(
            message,
            file: file,
            line: line
          )
        )
        .recording(value, for: "value"),
      path: path
    )
  }

  public var context: DiagnosticsContext
  public var path: Resource.FieldPath
}
