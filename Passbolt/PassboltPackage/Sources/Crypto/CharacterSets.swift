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

import struct Foundation.CharacterSet

internal enum CharacterSets: Sendable {

  case uppercaseLetters
  case lowercaseLetters
  case digits
  case parenthesis
  case specialChar1
  case specialChar2
  case specialChar3
  case specialChar4
  case specialChar5
  case emoji
  case alikeCharacters

  internal var characters: Set<Character> {
    switch self {
    case .uppercaseLetters:
      return Self.uppercaseLettersSet
    case .lowercaseLetters:
      return Self.lowercaseLettersSet
    case .digits:
      return Self.digitsSet
    case .parenthesis:
      return Self.parenthesisSet
    case .specialChar1:
      return Self.specialChar1Set
    case .specialChar2:
      return Self.specialChar2Set
    case .specialChar3:
      return Self.specialChar3Set
    case .specialChar4:
      return Self.specialChar4Set
    case .specialChar5:
      return Self.specialChar5Set
    case .emoji:
      return Self.emojiSet
    case .alikeCharacters:
      return .init([
        "O", "l", "|", "I", "0", "1",
      ])
    }
  }

  private static let lowercaseLettersSet: Set<Character> = .init([
    "a", "b", "c", "d", "e", "f",
    "g", "h", "i", "j", "k", "l",
    "m", "n", "o", "p", "q", "r",
    "s", "t", "u", "v", "w", "x",
    "y", "z",
  ])

  private static let uppercaseLettersSet: Set<Character> = .init([
    "A", "B", "C", "D", "E", "F",
    "G", "H", "I", "J", "K", "L",
    "M", "N", "O", "P", "Q", "R",
    "S", "T", "U", "V", "W", "X",
    "Y", "Z",
  ])

  private static let digitsSet: Set<Character> = .init([
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
  ])

  private static let parenthesisSet: Set<Character> = .init([
    "{", "(", "[", "|", "]", ")", "}",
  ])

  private static let specialChar1Set: Set<Character> = .init([
    "#", "$", "%", "&", "@", "^", "~",
  ])

  private static let specialChar2Set: Set<Character> = .init([
    ".", ",", ":", ";",
  ])

  private static let specialChar3Set: Set<Character> = .init([
    "'", "\"", "`",
  ])

  private static let specialChar4Set: Set<Character> = .init([
    "/", "\\", "_", "-",
  ])

  private static let specialChar5Set: Set<Character> = .init([
    "<", "*", "+", "!", "?", "=",
  ])

  private static let emojiSet: Set<Character> = .init([
    "😀", "😁", "😂", "😃", "😄", "😅", "😆", "😇", "😈", "😉",
    "😊", "😋", "😌", "😍", "😎", "😏", "😐", "😑", "😒", "😓",
    "😔", "😕", "😖", "😗", "😘", "😙", "😚", "😛", "😜", "😝",
    "😞", "😟", "😠", "😡", "😢", "😣", "😤", "😥", "😦", "😧",
    "😨", "😩", "😪", "😫", "😬", "😭", "😮", "😯", "😰", "😱",
    "😲", "😳", "😴", "😵", "😶", "😷", "😸", "😹", "😺", "😻",
    "😼", "😽", "😾", "😿", "🙀", "🙁", "🙂", "🙃", "🙄", "🙅",
    "🙆", "🙇", "🙈", "🙉", "🙊", "🙋", "🙌", "🙍", "🙎", "🙏",
  ])
}
