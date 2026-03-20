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

/// Root container view that connects NavigationState to SwiftUI navigation.
/// Provides NavigationStack with programmatic navigation support via NavigationState.
public struct NavigationContainer<Content: View>: View {

  @ObservedObject private var navigationState: NavigationState
  private let content: () -> Content

  public init(
    navigationState: NavigationState,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.navigationState = navigationState
    self.content = content
  }

  public var body: some View {
    NavigationStack(path: $navigationState.path) {
      content()
        .navigationDestination(for: AnyNavigationItem.self) { item in
          item.makeView()
            .environment(\.navigationState, navigationState)
        }
    }
    .sheet(item: sheetBinding) { item in
      item.makeView()

        .interactiveDismissDisabled()
        .presentationDragIndicator(.hidden)
        .solidPresentationBackground()
    }
    .sheet(item: partialSheetBinding) { item in
      item.makeView()

        .dynamicDetent()
        .interactiveDismissDisabled()
        .presentationDragIndicator(.hidden)
        .solidPresentationBackground()
    }
    .alert(
      alertTitle,
      isPresented: alertIsPresented,
      presenting: navigationState.presentedAlert,
      actions: { alert in
        ForEach(alert.actions) { action in
          Button(action.title, role: action.role.buttonRole) {
            action.action()
          }
        }
      },
      message: { alert in
        if let message = alert.message {
          Text(message)
        }
      }
    )
    .environment(\.navigationState, navigationState)
    .onChange(of: navigationState.path.count) { newValue in
      navigationState.synchronizeWithPath(newCount: newValue)
    }
  }

  private var sheetBinding: Binding<AnyNavigationItem?> {
    Binding(
      get: { navigationState.presentedSheet },
      set: { newValue in
        if newValue == nil {
          navigationState.sheetDismissed()
        }
      }
    )
  }

  private var partialSheetBinding: Binding<AnyNavigationItem?> {
    Binding(
      get: { navigationState.presentedPartialSheet },
      set: { newValue in
        if newValue == nil {
          navigationState.partialSheetDismissed()
        }
      }
    )
  }

  private var alertTitle: String {
    navigationState.presentedAlert?.title ?? ""
  }

  private var alertIsPresented: Binding<Bool> {
    Binding(
      get: { navigationState.presentedAlert != nil },
      set: { presented in
        if !presented {
          navigationState.alertDismissed()
        }
      }
    )
  }
}

extension NavigationContainer {

  /// Convenience initializer that creates a NavigationState internally.
  /// Use this when you don't need to share NavigationState with the feature system.
  public init(
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.init(navigationState: NavigationState(), content: content)
  }
}

private struct DynamicDetent: ViewModifier {
  @State private var height: CGFloat = 0
  private var currentHeight: CGFloat {
    max(height + 40, 100)
  }

  fileprivate func body(content: Content) -> some View {
    content
      .fixedSize(horizontal: false, vertical: true)
      .overlay {
        GeometryReader { reader in
          Color.clear.preference(
            key: ContentSizePreferenceKey.self,
            value: reader.size.height
          )
        }
      }
      .onPreferenceChange(ContentSizePreferenceKey.self) { height in
        self.height = height
      }
      .presentationDetents([.height(currentHeight)])
  }

  private struct ContentSizePreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
      value = nextValue()
    }
  }
}

extension View {

  @ViewBuilder
  internal func solidPresentationBackground() -> some View {
    if #available(iOS 16.4, *) {
      self.presentationBackground(Color.white)
    }
    else {
      self
    }
  }

  fileprivate func dynamicDetent() -> some View {
    self.modifier(DynamicDetent())
  }
}
