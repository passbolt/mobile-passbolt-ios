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
    // convert string to bytes using ASCII
    guard let stringData: Data = string.uppercased().data(using: .ascii, allowLossyConversion: false)
    else {
      return nil
    }

    // prepare input buffer
    let inputBuffer: UnsafeMutableRawBufferPointer = .allocate(
      // allocating exact or more than needed
      byteCount: stringData.count,
      alignment: 0
    )
    defer { inputBuffer.deallocate() }
    inputBuffer
      .initializeMemory(
        as: UInt8.self,
        repeating: 0
      )

    var inputBytesCount: Int = 0
    // iterate over string bytes and convert bytes
    // according to conversion table, fail on invalid
    // characters and count bytes for processing
    for (offset, element): (Int, UInt8) in stringData.enumerated() {
      // if value exists in table use it in input buffer
      if let code: UInt8 = base32DecodingTable[element] {
        inputBuffer[offset] = code
        inputBytesCount += 1
      }
      else if element == paddingByte {
        break  // skip padding, ends data
      }
      else {
        return nil  // invalid characters
      }
    }

    // prepare blocks count - number of octets (rounded up)
    // to be converted to output
    let blocksCount: Int = inputBytesCount / 8 + (inputBytesCount % 8 == 0 ? 0 : 1)

    // prepare output buffer
    let outputBufferBytesCount: Int = blocksCount * 5
    let outputBuffer: UnsafeMutableRawBufferPointer = .allocate(
      // allocating rounding up, empty bytes will be removed at the end
      byteCount: Swift.max(outputBufferBytesCount, 5),
      alignment: 0
    )
    outputBuffer
      .initializeMemory(
        as: UInt8.self,
        repeating: 0
      )
    guard let outputAddress: UnsafeMutableRawPointer = outputBuffer.baseAddress
    else { return nil }

    // prepare buffer for converting octets in blocks
    let blockBuffer: UnsafeMutableRawBufferPointer = .allocate(
      byteCount: 8,
      alignment: 0
    )
    defer { blockBuffer.deallocate() }

    for block: Int in 0 ..< blocksCount {
      // clear block buffer for each block
      blockBuffer
        .initializeMemory(
          as: UInt8.self,
          repeating: 0
        )

      let inputOffset: Int = block * 8
      // count number of bytes available in block,
      // it is 8 (octet) except possible reminder
      let blockBytesCount: Int = (inputOffset + 8 > inputBytesCount) ? inputBytesCount % 8 : 8

      // write bytes from input to block buffer
      for byteIndex: Int in 0 ..< blockBytesCount {
        blockBuffer[byteIndex] = inputBuffer[inputOffset + byteIndex]
      }

      // write bytes to output buffer
      let outputOffset: Int = block * 5
      outputBuffer[outputOffset + 0] = ((blockBuffer[0] << 3) & 0xF8) | ((blockBuffer[1] >> 2) & 0x07)
      outputBuffer[outputOffset + 1] =
        ((blockBuffer[1] << 6) & 0xC0) | ((blockBuffer[2] << 1) & 0x3E) | ((blockBuffer[3] >> 4) & 0x01)
      outputBuffer[outputOffset + 2] = ((blockBuffer[3] << 4) & 0xF0) | ((blockBuffer[4] >> 1) & 0x0F)
      outputBuffer[outputOffset + 3] =
        ((blockBuffer[4] << 7) & 0x80) | ((blockBuffer[5] << 2) & 0x7C) | ((blockBuffer[6] >> 3) & 0x03)
      outputBuffer[outputOffset + 4] = ((blockBuffer[6] << 5) & 0xE0) | (blockBuffer[7] & 0x1F)
    }

    // convert buffer to Data
    var resultData: Data = .init(
      bytesNoCopy: outputAddress,
      count: outputBufferBytesCount,
      deallocator: .free
    )

    // remove trailing zeros
    while resultData.last == 0 {
      resultData.removeLast()
    }

    // finalize init
    self = resultData
  }
}

// 61 is ASCII code for `=` which is used for padding
private let paddingByte: UInt8 = 61
private let base32DecodingTable: Dictionary<UInt8, UInt8> = [
  // ASCII codes -> values
  65: 0, 66: 1, 67: 2, 68: 3,
  69: 4, 70: 5, 71: 6, 72: 7,
  73: 8, 74: 9, 75: 10, 76: 11,
  77: 12, 78: 13, 79: 14, 80: 15,
  81: 16, 82: 17, 83: 18, 84: 19,
  85: 20, 86: 21, 87: 22, 88: 23,
  89: 24, 90: 25, 50: 26, 51: 27,
  52: 28, 53: 29, 54: 30, 55: 31,
]
