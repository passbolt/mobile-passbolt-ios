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

import Display

internal struct LogsViewerView: ControlledView {

  internal let controller: LogsViewerViewController

  internal init(controller: LogsViewerViewController) {
    self.controller = controller
  }

  internal var body: some View {
    withSheet(
      \.presentShareSheet,
      sheet: {
        with(\.sharingDiagnosticsInfo) { diagnosticsInfo in
          ActivityViewController(
            activityItems: diagnosticsInfo
          )
        }
      },
      content: {
        VStack(spacing: 0) {
          HStack(spacing: 0) {
            AsyncButton(
              action: {
                await self.controller.close()
              },
              label: {
                Image(named: .close)
                  .resizable()
                  .renderingMode(.template)
                  .foregroundStyle(Color.passboltPrimaryText)
                  .frame(width: 20, height: 20)
              }
            )
            Spacer()
            Text(displayable: "help.logs.viewer.title")
              .font(.inter(ofSize: 16, weight: .semibold))
              .foregroundStyle(Color.passboltPrimaryText)

            Spacer()
            AsyncButton(
              action: {
                await self.controller.share()
              },
              label: {
                Image(named: .open)
                  .resizable()
                  .renderingMode(.template)
                  .foregroundStyle(Color.passboltPrimaryText)
                  .frame(width: 20, height: 20)
              }
            )
          }
          .padding(16)

          with(\.isInitialLoading) { isInitialLoading in
            if isInitialLoading {
              VStack(spacing: 0) {
                Spacer()
                ActivityIndicator(style: .large)
                  .task {
                    await controller.refreshLogs()
                  }
                Spacer()
              }
            }
            else {
              with(\.diagnosticsInfo) { info in
                List {
                  ForEach(info, id: \.self) { line in
                    Text(line)
                      .font(.system(size: 10))
                      .monospaced()
                      .foregroundStyle(Color.passboltPrimaryText)
                  }
                }
                .listStyle(.plain)
              }
            }
          }
        }
      }
    )
  }
}

private struct ActivityViewController: UIViewControllerRepresentable {
  private let activityItems: [Any]
  private let applicationActivities: [UIActivity]?
  @Environment(\.presentationMode) var presentationMode

  fileprivate init(
    activityItems: [Any],
    applicationActivities: [UIActivity]? = nil
  ) {
    self.activityItems = activityItems
    self.applicationActivities = applicationActivities
  }

  fileprivate func makeUIViewController(context: Context)
    -> UIActivityViewController
  {
    let controller = UIActivityViewController(
      activityItems: activityItems,
      applicationActivities: applicationActivities
    )
    controller.completionWithItemsHandler = { _, _, _, _ in
      self.presentationMode.wrappedValue.dismiss()
    }
    return controller
  }

  fileprivate func updateUIViewController(
    _ uiViewController: UIActivityViewController,
    context: Context
  ) {
    // no updates needed
  }
}

#if DEBUG

#Preview {
  PlaceholderView()
    .sheet(
      isPresented: .constant(true)
    ) {
      createPreview(LogsViewerView.self)
    }
}

#endif
