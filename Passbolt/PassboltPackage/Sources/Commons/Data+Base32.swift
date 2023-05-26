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

import struct Foundation.Data

extension Data {

  public init?(
    base32Encoded string: String
  ) {
    let data: Data? = string.utf8CString.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> Data? in
      // utf8CString is null terminated, actual data is 1 element less
      let inputBufferSize: Int = buffer.count - 1
      let outputBuffer: UnsafeMutableRawBufferPointer = .allocate(
        // allocating rounding up, empty bytes will be skipped at the end
        byteCount: inputBufferSize + inputBufferSize % 5,
        alignment: 0
      )
      outputBuffer
        .initializeMemory(
          as: UInt8.self,
          repeating: 0
        )
      defer { outputBuffer.deallocate() }

      guard let outputAddress: UnsafeMutableRawPointer = outputBuffer.baseAddress
      else { return nil }

      var outputBufferSize: Int = 0
      var index: Int = 0
      while index < inputBufferSize {
        if let code: UInt8 = base32DecodingTable[buffer[index]] {
          let outputIndex: Int = index * 5 / 8
          switch index % 8 {
          case 0:
            outputBuffer[outputIndex] = (code << 3) & 0b11111000
            // unfinished octets does not count to output

          case 1:
            outputBuffer[outputIndex] = outputBuffer[outputIndex] | ((code >> 2) & 0b00000111)
            outputBuffer[outputIndex + 1] = (code << 6) & 0b11000000
            outputBufferSize += 1

          case 2:
            outputBuffer[outputIndex] = outputBuffer[outputIndex] | ((code << 1) & 0b00111110)
            // unfinished octets does not count to output

          case 3:
            outputBuffer[outputIndex] = outputBuffer[outputIndex] | ((code >> 4) & 0b00000001)
            outputBuffer[outputIndex + 1] = (code << 4) & 0b11110000
            outputBufferSize += 1

          case 4:
            outputBuffer[outputIndex] = outputBuffer[outputIndex] | ((code >> 1) & 0b00001111)
            outputBuffer[outputIndex + 1] = (code << 7) & 0b10000000
            outputBufferSize += 1

          case 5:
            outputBuffer[outputIndex] = outputBuffer[outputIndex] | ((code << 2) & 0b01111100)
            // unfinished octets does not count to output

          case 6:
            outputBuffer[outputIndex] = outputBuffer[outputIndex] | ((code >> 3) & 0b00000011)
            outputBuffer[outputIndex + 1] = (code << 5) & 0b11100000
            outputBufferSize += 1

          case 7:
            outputBuffer[outputIndex] = outputBuffer[outputIndex] | (code & 0b00011111)
            outputBufferSize += 1

          case _:
            unreachable("% 8 can't exceed 7")
          }
          index += 1
        }
        else if buffer[index] == paddingByte {
          break  // padding ends data
        }
        else {
          return nil  // invalid characters
        }
      }

      return .init(
        bytes: outputAddress,
        count: outputBufferSize
      )
    }

    if let data {
      self = data
    }
    else {
      return nil
    }
  }
}

// 61 is ASCII code for `=` which is used for padding
private let paddingByte: UInt8 = 61
private let base32DecodingTable: Dictionary<UInt8, UInt8> = [
  // ASCII codes (uppercased and lowercased) -> values
  65: 0, 66: 1, 67: 2, 68: 3,
  69: 4, 70: 5, 71: 6, 72: 7,
  73: 8, 74: 9, 75: 10, 76: 11,
  77: 12, 78: 13, 79: 14, 80: 15,
  81: 16, 82: 17, 83: 18, 84: 19,
  85: 20, 86: 21, 87: 22, 88: 23,
  89: 24, 90: 25, 50: 26, 51: 27,
  52: 28, 53: 29, 54: 30, 55: 31,
  97: 0, 98: 1, 99: 2, 100: 3,
  101: 4, 102: 5, 103: 6, 104: 7,
  105: 8, 106: 9, 107: 10, 108: 11,
  109: 12, 110: 13, 111: 14, 112: 15,
  113: 16, 114: 17, 115: 18, 116: 19,
  117: 20, 118: 21, 119: 22, 120: 23,
  121: 24, 122: 25,
]
