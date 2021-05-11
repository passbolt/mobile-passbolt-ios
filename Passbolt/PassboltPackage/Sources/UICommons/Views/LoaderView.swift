import AegithalosCocoa

public final class LoaderOverlayView: View {

  private let activityIndicator: UIActivityIndicatorView = .init(style: .medium)
  private let label: Label = .init()
  
  public required init() {
    super.init()
    dynamicBackgroundColor = .overlayBackground
    let containerView: View = Mutation
      .combined(
        .backgroundColor(dynamic: .divider),
        .cornerRadius(8, masksToBounds: true),
        .subview(of: self),
        .widthAnchor(.equalTo, constant: 96),
        .heightAnchor(.equalTo, constant: 96),
        .centerYAnchor(.equalTo, centerYAnchor, constant: 8),
        .centerXAnchor(.equalTo, centerXAnchor)
      )
      .instantiate()
    
    #warning("TODO: localizable strings")
    Mutation<Label>
      .combined(
        .font(.inter(ofSize: 12, weight: .medium)),
        .textAlignment(.center),
        .numberOfLines(1),
        .textColor(dynamic: .primaryText),
        .text("Loading..."),
        .subview(of: containerView),
        .leadingAnchor(.equalTo, containerView.leadingAnchor, constant: 8),
        .trailingAnchor(.equalTo, containerView.trailingAnchor, constant: -8),
        .bottomAnchor(.equalTo, containerView.bottomAnchor, constant: -16)
      )
      .instantiate()
    
    mut(activityIndicator) {
      .combined(
        .subview(of: containerView),
        .centerYAnchor(.equalTo, centerYAnchor),
        .centerXAnchor(.equalTo, centerXAnchor)
      )
    }
  }
  
  override public func willMove(
    toWindow newWindow: UIWindow?
  ) {
    super.willMove(toWindow: newWindow)
    if newWindow != nil {
      activityIndicator.startAnimating()
    } else {
      activityIndicator.stopAnimating()
    }
  }
  
  override public func traitCollectionDidChange(
    _ previousTraitCollection: UITraitCollection?
  ) {
    super.traitCollectionDidChange(previousTraitCollection)
    activityIndicator.color = DynamicColor.icon(in: traitCollection.userInterfaceStyle)
  }
}
