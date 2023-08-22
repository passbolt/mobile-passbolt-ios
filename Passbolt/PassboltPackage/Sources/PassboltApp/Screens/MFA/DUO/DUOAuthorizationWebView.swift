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
import WebKit
import CommonModels
import UICommons
import AegithalosCocoa

internal struct DUOAuthorizationWebView: UIViewRepresentable {

	private let request: DUOWebAuthorizationRequest
	private let receiveTokens: @MainActor (String, String, String) -> Void
	private let handleFailure: @MainActor (Error) -> Void

	internal init(
		request: DUOWebAuthorizationRequest,
		receiveTokens: @escaping @MainActor (String, String, String) -> Void,
		handleFailure: @escaping @MainActor (Error) -> Void
	) {
		self.request = request
		self.receiveTokens = receiveTokens
		self.handleFailure = handleFailure
	}

	internal func makeUIView(
		context: Context
	) -> WKWebView {
		DUOWebView(
			request: self.request,
			receiveTokens: self.receiveTokens,
			handleFailure: self.handleFailure
		)
	}

	internal func updateUIView(
		_ uiView: WKWebView,
		context: Context
	) {
		guard let webView: DUOWebView = uiView as? DUOWebView
		else { return assertionFailure("Invalid web view type!") }
		webView.updateRequest(self.request)
	}
}

internal struct DUOWebAuthorizationRequest: Equatable, Identifiable {

	// each request contains token in url query
	// allowing to identify a request just by url
	internal var id: URL { self.url }

	internal var url: URL
	internal var token: String
}

private final class DUOWebView: WKWebView, WKNavigationDelegate, UIScrollViewDelegate {

	private var request: DUOWebAuthorizationRequest
	private let receiveTokens: @MainActor (String, String, String) -> Void
	private let handleFailure: @MainActor (Error) -> Void

	@MainActor fileprivate init(
		request: DUOWebAuthorizationRequest,
		receiveTokens: @escaping @Sendable (String, String, String) -> Void,
		handleFailure: @escaping @Sendable (Error) -> Void
	) {
		self.request = request
		self.receiveTokens = receiveTokens
		self.handleFailure = handleFailure
		let configuration: WKWebViewConfiguration = .init()
		configuration.websiteDataStore = .nonPersistent()
		super.init(
			frame: .zero,
			configuration: configuration
		)
		self.navigationDelegate = self
		self.scrollView.isScrollEnabled = false
		self.scrollView.minimumZoomScale = 1
		self.scrollView.maximumZoomScale = 1
		self.scrollView.delegate = self
		self.requestAuthorization()
	}

	@available(*, unavailable)
	fileprivate required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	@MainActor fileprivate func updateRequest(
		_ request: DUOWebAuthorizationRequest
	) {
		guard self.request != request else { return }
		self.request = request
		self.requestAuthorization()
	}

	@MainActor private func requestAuthorization() {
		let request: URLRequest = .init(
			url: self.request.url,
			cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
			timeoutInterval: 30
		)
		self.load(request)
	}

	fileprivate func webView(
		_ webView: WKWebView,
		didFinish navigation: WKNavigation!
	) {
		// customize DUO css settings...
		self.evaluateJavaScript(
			"""
			document.body.style.background='#ffffff';
			document.body.children[0].style.margin='0';
			"""
		)
	}

	fileprivate func webView(
		_ webView: WKWebView,
		didFail navigation: WKNavigation!,
		withError error: Error
	) {
		self.handleFailure(error)
	}

	fileprivate func webView(
		_ webView: WKWebView,
		decidePolicyFor navigationAction: WKNavigationAction
	) async -> WKNavigationActionPolicy {
		guard // check if request is a callback to passbolt
			case .formSubmitted = navigationAction.navigationType,
			let url: URL = navigationAction.request.url,
			url.relativePath.hasSuffix("/mfa/verify/duo/callback")
		else { return .allow }

		guard // check if it contains duo code and state token
			let query: String = navigationAction.request.url?.query,
			let codeRange = query.range(of: "duo_code="),
			let stateRange = query.range(of: "state=")
		else {
			self.handleFailure(DUOAuthorizationFailure.error())
			return .cancel
		}

		self.receiveTokens(
			String( // find duo code
				query[codeRange.upperBound...]
					.prefix(
						while: { !$0.isWhitespace && $0 != "&" }
					)
			),
			String( // find duo state token
				query[stateRange.upperBound...]
					.prefix(
						while: { !$0.isWhitespace && $0 != "&" }
					)
			),
			// use passbolt state token from request
			self.request.token
		)
		return .cancel
	}

	fileprivate func viewForZooming(
		in scrollView: UIScrollView
	) -> UIView? {
		.none // prevent zoom
	}
}
