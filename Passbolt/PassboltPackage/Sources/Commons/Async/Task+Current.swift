// code from: https://gist.github.com/KaQuMiQ/a3a73bfd7ff4b41c7d231a1ce1555bde

extension Optional
where Wrapped == Task<Void, Never> {

  @_transparent internal mutating func clearIfCurrent() {
    switch self {
    case .some(let task) where task.isCurrent:
      self = .none

    case _:
      break  // noop
    }
  }
}

extension Task {

  fileprivate var isCurrent: Bool {
    withUnsafeCurrentTask { (unsafeTask: UnsafeCurrentTask?) -> Bool in
      guard let unsafeTask else { return false }

      return withUnsafePointer(to: self) { (selfPointer: UnsafePointer<Task>) -> Bool in
        selfPointer.withMemoryRebound(to: TaskBox.self, capacity: 1) {
          (selfBoxPointer: UnsafePointer<TaskBox>) -> Bool in
          withUnsafePointer(to: unsafeTask) { (currentPointer: UnsafePointer<UnsafeCurrentTask>) -> Bool in
            currentPointer.withMemoryRebound(to: TaskBox.self, capacity: 1) {
              (currentBoxPointer: UnsafePointer<TaskBox>) -> Bool in
              selfBoxPointer.pointee._task == currentBoxPointer.pointee._task
            }
          }
        }
      }
    }
  }
}

// https://github.com/apple/swift/blob/750545774b4505064af1f144a24c1177e8515250/stdlib/public/Concurrency/Task.swift#L81
// https://github.com/apple/swift/blob/750545774b4505064af1f144a24c1177e8515250/stdlib/public/Concurrency/Task.swift#L870
// https://github.com/apple/swift/blob/750545774b4505064af1f144a24c1177e8515250/docs/SIL.rst#ref-to-raw-pointer
private struct TaskBox {
  // builtin reference (Builtin.RawPointer) uses platform long Int for pointers
  fileprivate let _task: Int
}
