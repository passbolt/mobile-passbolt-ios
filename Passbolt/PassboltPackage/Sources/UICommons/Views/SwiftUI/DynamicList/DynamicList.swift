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

import Commons

/// A high-performance virtual scrolling list that only renders items within the visible viewport.
///
/// `DynamicList` uses a custom `Layout` to position items based on their estimated heights,
/// rendering only the currently visible subset. This avoids the overhead of materializing all
/// SwiftUI views for large datasets.
///
/// On iOS 18+, native `onScrollGeometryChange` is used for scroll tracking.
/// On iOS 16–17, a `PreferenceKey`-based backport provides equivalent functionality.
///
/// - Parameters:
///   - items: The full array of items conforming to ``DynamicListItem``.
///   - hasMoreData: Whether additional data can be loaded via infinite scroll.
///   - isLoadingMore: Whether a load-more operation is currently in progress.
///   - onLoadMore: Async closure invoked when the scroll position nears the end of content.
///   - content: A view builder that produces the view for each item.
///   - loadMoreThreshold: Number of items from the end at which `onLoadMore` is triggered. Defaults to 10.
public struct DynamicList<ItemType, Content: View>: View where ItemType: DynamicListItem {

  private let items: Array<ItemType>
  private var numberOfItems: Int { items.count }
  private let hasMoreData: Bool
  private let isLoadingMore: Bool
  private let onLoadMore: @Sendable () async -> Void
  private let refreshAction: (@Sendable () async -> Void)?
  private let refreshIndicatorSource: AnyUpdatable<Bool>?
  private let contentResetToken: Int
  private let loadMoreThreshold: Int
  @State private var visibleRange: Range<Int> = 0 ..< 1
  @State private var hasTriggeredLoadMore: Bool = false
  @State private var previousItemCount: Int = 0
  @State private var lastVisibleRect: CGRect = .zero
  @State private var viewportSize: CGSize = .zero
  @ViewBuilder private var content: (ItemType) -> Content

  /// Fallback viewport size derived from the device screen when geometry data is not yet available.
  private var fallbackViewportSize: CGSize {
    let screenBounds: CGRect = UIScreen.main.bounds
    return CGSize(
      width: screenBounds.width > 0 ? screenBounds.width : 375,
      height: screenBounds.height > 0 ? screenBounds.height * 0.8 : 600
    )
  }

  public init(
    items: Array<ItemType>,
    hasMoreData: Bool,
    isLoadingMore: Bool,
    onLoadMore: @Sendable @escaping () async -> Void,
    refreshAction: (@Sendable () async -> Void)? = nil,
    refreshIndicatorSource: AnyUpdatable<Bool>? = nil,
    contentResetToken: Int = 0,
    content: @escaping (ItemType) -> Content,
    loadMoreThreshold: Int = 10
  ) {
    self.items = items
    self.hasMoreData = hasMoreData
    self.isLoadingMore = isLoadingMore
    self.onLoadMore = onLoadMore
    self.refreshAction = refreshAction
    self.refreshIndicatorSource = refreshIndicatorSource
    self.contentResetToken = contentResetToken
    self.content = content
    self.loadMoreThreshold = loadMoreThreshold
  }

  // MARK: - Body

  public var body: some View {
    if #available(iOS 18.0, *) {
      nativeScrollView
    }
    else {
      backportScrollView
    }
  }

  // MARK: - iOS 18+ (native scroll geometry tracking)
  @available(iOS 18.0, *)
  private var nativeScrollView: some View {
    ScrollViewReader { proxy in
      ScrollView(.vertical) {
        Color.clear
          .frame(width: 0, height: 0)
          .id(topAnchorID)
        offsetLayoutContent
      }
      .onScrollGeometryChange(for: ScrollUpdate.self) { geometry in
        let visibleRect: CGRect = CGRect(
          x: geometry.contentOffset.x,
          y: geometry.contentOffset.y,
          width: geometry.containerSize.width,
          height: geometry.containerSize.height
        )
        return ScrollUpdate(
          visibleRect: visibleRect,
          visibleRange: self.computeVisibleRange(in: visibleRect)
        )
      } action: { _, newValue in
        self.lastVisibleRect = newValue.visibleRect
        self.visibleRange = newValue.visibleRange
        self.checkIfNeedToLoadMore()
      }
      .refreshableWithIndicator(
        refreshAction: self.refreshAction,
        refreshIndicatorSource: self.refreshIndicatorSource
      )
      .onAppear {
        recomputeVisibleRange()
      }
      .onChange(of: numberOfItems) { _, newValue in
        handleItemCountChange(newValue)
      }
      .onChange(of: contentResetToken) { _, _ in
        proxy.scrollTo(topAnchorID, anchor: .top)
      }
    }
  }

  // MARK: - iOS 16-17 (PreferenceKey-based scroll tracking)
  private var backportScrollView: some View {
    ScrollViewReader { scrollProxy in
      ScrollView(.vertical) {
        Color.clear
          .frame(width: 0, height: 0)
          .id(topAnchorID)
        offsetLayoutContent
          .background(
            GeometryReader { proxy in
              Color.clear
                .preference(
                  key: ScrollContentOffsetPreferenceKey.self,
                  value: proxy.frame(in: .named(scrollCoordinateSpaceName)).origin
                )
            }
          )
      }
      .coordinateSpace(name: scrollCoordinateSpaceName)
      .background(
        GeometryReader { proxy in
          Color.clear
            .preference(key: ViewportSizePreferenceKey.self, value: proxy.size)
        }
      )
      .onPreferenceChange(ViewportSizePreferenceKey.self) { size in
        viewportSize = size
      }
      .onPreferenceChange(ScrollContentOffsetPreferenceKey.self) { offset in
        guard let offset: CGPoint = offset else { return }
        let height: CGFloat = viewportSize.height > 0 ? viewportSize.height : fallbackViewportSize.height
        let width: CGFloat = viewportSize.width > 0 ? viewportSize.width : fallbackViewportSize.width
        let visibleRect: CGRect = CGRect(
          x: -offset.x,
          y: -offset.y,
          width: width,
          height: height
        )
        self.lastVisibleRect = visibleRect
        let newRange: Range<Int> = self.computeVisibleRange(in: visibleRect)
        if newRange != self.visibleRange {
          self.visibleRange = newRange
          self.checkIfNeedToLoadMore()
        }
      }
      .refreshableWithIndicator(
        refreshAction: self.refreshAction,
        refreshIndicatorSource: self.refreshIndicatorSource
      )
      .onAppear {
        recomputeVisibleRange()
      }
      .onChangeBackport(of: numberOfItems) { _, newValue in
        handleItemCountChange(newValue)
      }
      .onChange(of: contentResetToken) { _ in
        scrollProxy.scrollTo(topAnchorID, anchor: .top)
      }
    }
  }

  // MARK: - Shared layout content
  private var offsetLayoutContent: some View {
    OffsetLayout(
      itemsCount: items.count,
      itemHeights: items.map { $0.estimatedHeight }
    ) {
      ForEach(visibleRows) { item in
        content(item.value)
          .layoutValue(
            key: LayoutIndex.self,
            value: item.index
          )
          .accessibilityIdentifier(item.value.accessibilityIdentifier)
      }
    }
  }

  // MARK: - Helpers
  private func handleItemCountChange(_ newValue: Int) {
    if newValue != previousItemCount {
      hasTriggeredLoadMore = false
      recomputeVisibleRange()
    }
    previousItemCount = newValue
  }

  private func recomputeVisibleRange() {
    let rect: CGRect =
      lastVisibleRect != .zero
      ? lastVisibleRect
      : CGRect(x: 0, y: 0, width: fallbackViewportSize.width, height: fallbackViewportSize.height)
    let newRange: Range<Int> = computeVisibleRange(in: rect)
    visibleRange = newRange
    checkIfNeedToLoadMore()
  }

  private func computeVisibleRange(in rect: CGRect) -> Range<Int> {
    guard !items.isEmpty else { return 0 ..< 0 }

    var currentY: CGFloat = 0
    var lowerBound: Int? = nil
    var upperBound: Int? = nil

    for (index, item) in items.enumerated() {
      let itemHeight: CGFloat = item.estimatedHeight
      let nextY: CGFloat = currentY + itemHeight

      if nextY > rect.minY && lowerBound == nil {
        lowerBound = index
      }

      if currentY < rect.maxY {
        upperBound = index + 1
      }
      else if lowerBound != nil {
        break
      }

      currentY = nextY
    }

    let lower: Int = lowerBound ?? 0
    let upper: Int = max(upperBound ?? 0, lower + 1)

    return lower ..< min(upper, items.count)
  }

  private func checkIfNeedToLoadMore() {
    guard hasMoreData, !isLoadingMore, !hasTriggeredLoadMore else { return }

    let threshold: Int = max(0, numberOfItems - loadMoreThreshold)
    if visibleRange.upperBound >= threshold {
      hasTriggeredLoadMore = true
      Task { @MainActor in
        await onLoadMore()
      }
    }
  }

  private var visibleRows: Array<ItemWrapper> {
    if items.isEmpty { return .init() }

    let lowerBound: Int = min(
      max(0, visibleRange.lowerBound),
      items.count - 1
    )
    let upperBound: Int = max(
      min(items.count, visibleRange.upperBound),
      lowerBound + 1
    )

    let range: Range<Int> = lowerBound ..< upperBound
    let rowSlice: ArraySlice<ItemType> = items[lowerBound ..< upperBound]

    return zip(rowSlice, range)
      .map { row in
        ItemWrapper(
          fragmentID: row.1,
          index: row.1,
          value: row.0,
          itemID: row.0.id
        )
      }
  }

  private struct ScrollUpdate: Equatable {
    let visibleRect: CGRect
    let visibleRange: Range<Int>
  }

  private struct ItemWrapper: Identifiable {
    let fragmentID: Int
    let index: Int
    let value: ItemType
    let itemID: ItemType.ID

    var id: ItemType.ID { itemID }

    init(fragmentID: Int, index: Int, value: ItemType, itemID: ItemType.ID) {
      self.fragmentID = fragmentID
      self.index = index
      self.value = value
      self.itemID = itemID
    }
  }
}

// MARK: - Constants
private let scrollCoordinateSpaceName: String = "dynamicListScrollView"
private let topAnchorID: String = "__dynamicListTop__"

private struct OffsetLayout: Layout {
  private let itemsCount: Int
  private let itemHeights: Array<CGFloat>
  private let defaultItemHeight: CGFloat

  init(itemsCount: Int, itemHeights: Array<CGFloat>, defaultItemHeight: CGFloat = 64) {
    self.itemsCount = itemsCount
    self.itemHeights = itemHeights
    self.defaultItemHeight = defaultItemHeight
  }

  func sizeThatFits(
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout ()
  ) -> CGSize {
    let totalHeight: CGFloat = itemHeights.reduce(0, +)
    return CGSize(
      width: proposal.width ?? 0,
      height: totalHeight
    )
  }

  func placeSubviews(
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout ()
  ) {
    for subview in subviews {
      let index: Int = subview[LayoutIndex.self]
      let itemHeight: CGFloat = index < itemHeights.count ? itemHeights[index] : defaultItemHeight

      let yOffset: CGFloat = itemHeights.prefix(index).reduce(0, +)

      subview.place(
        at: CGPoint(
          x: bounds.midX,
          y: bounds.minY + yOffset
        ),
        anchor: .top,
        proposal: .init(
          width: proposal.width,
          height: itemHeight
        )
      )
    }
  }
}

// MARK: - Layout Keys

private struct LayoutIndex: LayoutValueKey {
  static let defaultValue: Int = 0
  typealias Value = Int
}

// MARK: - Refresh modifier

private struct RefreshableWithIndicator: ViewModifier {

  fileprivate let refreshAction: (@Sendable () async -> Void)?
  fileprivate let refreshIndicatorSource: AnyUpdatable<Bool>?
  @State private var userPullingRefresh: Bool = false
  @State private var externalRefreshing: Bool = false

  fileprivate func body(content: Content) -> some View {
    content
      .refreshable {
        withAnimation(.easeInOut(duration: 0.25)) {
          self.userPullingRefresh = true
        }
        defer {
          withAnimation(.easeInOut(duration: 0.25)) {
            self.externalRefreshing = false
            self.userPullingRefresh = false
          }
        }
        await self.refreshAction?()
      }
      .safeAreaInset(edge: .top, spacing: 0) {
        if self.externalRefreshing && !self.userPullingRefresh {
          HStack {
            Spacer()
            // System-initiated refresh has no native `.refreshable` spinner, so this stands in for it.
            // It uses the same UIKit `UIActivityIndicatorView` that `UIRefreshControl` (the pull spinner) is
            // built from, so size, spin speed, and color all match — a SwiftUI `ProgressView` is a different
            // renderer and visibly differs in all three. The two never appear at the same time.
            RefreshActivityIndicator(color: .passboltSecondaryText)
              .scaleEffect(0.8)
            Spacer()
          }
          .padding(.vertical, 12)
        }
        else {
          Color.clear.frame(width: 0, height: 0)
        }
      }
      .task {
        guard let source: AnyUpdatable<Bool> = self.refreshIndicatorSource
        else { return }
        var iterator: UpdatableIterator<Bool> = source.makeAsyncIterator()
        while let update: Update<Bool> = await iterator.next() {
          let newValue: Bool = (try? update.value) ?? false
          withAnimation(.easeInOut(duration: 0.25)) {
            self.externalRefreshing = newValue
          }
        }
      }
  }
}

extension View {

  fileprivate func refreshableWithIndicator(
    refreshAction: (@Sendable () async -> Void)?,
    refreshIndicatorSource: AnyUpdatable<Bool>?
  ) -> some View {
    self.modifier(
      RefreshableWithIndicator(
        refreshAction: refreshAction,
        refreshIndicatorSource: refreshIndicatorSource
      )
    )
  }
}

// MARK: - Activity indicator

/// `UIActivityIndicatorView` wrapper used for the system-initiated refresh spinner so it matches the
/// `UIRefreshControl` spinner driven by `.refreshable` — same renderer means identical size, spin speed,
/// and color. (Note: the spinner color is set via `color`, not `tintColor`, which the view ignores.)
private struct RefreshActivityIndicator: UIViewRepresentable {

  fileprivate let color: UIColor
  /// Slows the rotation: a standalone `UIActivityIndicatorView` spins faster than `UIRefreshControl`'s, so
  /// damping the layer time scale matches the pull-to-refresh spinner. Tune toward 1.0 if it looks too slow.
  fileprivate var speed: Float = 0.65
  @Environment(\.colorScheme) private var colorScheme

  fileprivate func makeUIView(context: Context) -> UIActivityIndicatorView {
    let indicator: UIActivityIndicatorView = .init(style: .large)
    indicator.hidesWhenStopped = false
    indicator.layer.speed = self.speed
    self.apply(to: indicator)
    indicator.startAnimating()
    return indicator
  }

  fileprivate func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {
    uiView.layer.speed = self.speed
    self.apply(to: uiView)
    if !uiView.isAnimating {
      uiView.startAnimating()
    }
  }

  /// Resolve the dynamic color against the current scheme. A `UIView` inside a representable does not reliably
  /// adopt the SwiftUI color scheme, so the asset's light-mode (darker) variant can leak into dark mode.
  private func apply(to indicator: UIActivityIndicatorView) {
    let traits: UITraitCollection = .init(userInterfaceStyle: self.colorScheme == .dark ? .dark : .light)
    indicator.color = self.color.resolvedColor(with: traits)
  }
}

// MARK: - Preference Keys

private struct ScrollContentOffsetPreferenceKey: PreferenceKey {
  static let defaultValue: CGPoint? = nil
  static func reduce(value: inout CGPoint?, nextValue: () -> CGPoint?) {
    value = nextValue() ?? value
  }
}

private struct ViewportSizePreferenceKey: PreferenceKey {
  static let defaultValue: CGSize = .zero
  static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
    value = nextValue()
  }
}

extension View {
  @ViewBuilder
  fileprivate func onChangeBackport<V: Equatable>(
    of value: V,
    initial: Bool = false,
    _ action: @escaping (_ oldValue: V, _ newValue: V) -> Void
  ) -> some View {
    if #available(iOS 17, *) {
      self.onChange(of: value, initial: initial, action)
    }
    else {
      self.modifier(OnChangeBackportModifier(value: value, initial: initial, action: action))
    }
  }
}
/// Backport implementation of `onChange` for iOS 16 and earlier, using a `ViewModifier` and `@State` to track the old value.
private struct OnChangeBackportModifier<V: Equatable>: ViewModifier {
  private let value: V
  private let initial: Bool
  private let action: (_ oldValue: V, _ newValue: V) -> Void

  @State private var oldValue: V

  fileprivate init(value: V, initial: Bool, action: @escaping (_ oldValue: V, _ newValue: V) -> Void) {
    self.value = value
    self.initial = initial
    self.action = action
    self._oldValue = State(initialValue: value)
  }

  fileprivate func body(content: Content) -> some View {
    content
      .onAppear {
        if initial {
          action(value, value)
        }
      }
      .onChange(of: value) { newValue in
        action(oldValue, newValue)
        oldValue = newValue
      }
  }
}

extension View {

  @ViewBuilder
  public func accessibilityIdentifier(_ identifier: String?) -> some View {
    if let identifier {
      self.accessibilityIdentifier(identifier)
    }
    else {
      self
    }
  }
}
