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

import SwiftUI

public struct CommonList<Content>: View
where Content: View {

  private let content: @MainActor () -> Content

  public init(
    @ViewBuilder content: @escaping @MainActor () -> Content
  ) {
    self.content = content
  }

  public var body: some View {
    List(content: self.content)
      .listStyle(.plain)
      .environment(\.defaultMinListRowHeight, 32)  // allows smaller rows
      .environment(\.defaultMinListHeaderHeight, 16)  // allows smaller headers
      .foregroundColor(.passboltPrimaryText)
      .backgroundColor(.passboltBackground)
      .backport.hidesKeyboardOnScroll()
      .backport.hideScrollContentBackground()
      .clipped()
  }
}

#if DEBUG

internal struct CommonList_Previews: PreviewProvider {

  internal static var previews: some View {
    CommonList {
      CommonListSection(
        header: {
          Text("Custom header")
        },
        content: {
          CommonListRow(
            content: {
              Text("One line")
                .padding(
                  top: 8,
                  bottom: 8
                )
            },
            accessory: {
              CopyButtonImage()
            }
          )
        }
      )

      CommonListSection(
        header: {
          Text("Custom header")
        },
        content: {
          CommonListRow(
            content: {
              Text(
                "Item with really long text that wont fit in one or two lines but rather more to fill possible space and see how it behaves when longer string than expected with minimal size will became put inside row"
              )
              .padding(
                top: 8,
                bottom: 8
              )
            },
            accessory: {
              CopyButtonImage()
            }
          )
        }
      )

      CommonListSection(
        header: {
          Text("List header")
        },
        content: {
          ForEach((0 ... 10), id: \.self) { idx in
            CommonListRow(
              content: {
                Text("Item \(idx)")
                  .padding(
                    top: 8,
                    bottom: 8
                  )
              },
              accessory: {
                CopyButtonImage()
              }
            )
          }
        }
      )

      ForEach((0 ... 10), id: \.self) { idx in
        CommonListSection {
          CommonListRow(
            content: {
              Text("No header item \(idx)")
                .padding(
                  top: 8,
                  bottom: 8
                )
            },
            accessory: {
              CopyButtonImage()
            }
          )
        }
      }

      ForEach((0 ... 10), id: \.self) { idx in
        CommonListSection(
          header: {
            Text("Header list \(idx)")
          },
          content: {
            CommonListRow(
              content: {
                Text("Header item \(idx)")
                  .padding(
                    top: 8,
                    bottom: 8
                  )
              },
              accessory: {
                CopyButtonImage()
              }
            )
          }
        )
      }

      CommonListSpacer()
    }
  }
}
#endif
