//
//  PockUpdater.swift
//  Pock
//
//  Created by Pierluigi Galdi on 11/01/21.
//  Copyright © 2021 Pierluigi Galdi. All rights reserved.
//

import Foundation

internal struct Version: Codable {
	let name: String
	let link: URL
	let changelog: String
	let core_min: String?
}

internal struct VersionModel {
	let version: Version?
	let error: String?
}

internal struct LatestReleases: Codable {
	let core: Version
	let widgets: [String: Version]
}

internal class PockUpdater {
	
	/// Endpoint
	#if DEBUG
	private let latestVersionURLString: String = "https://pock.dev/api/dev/latestVersions.json"
	#else
	private let latestVersionURLString: String = "https://pock.dev/api/latestVersions.json"
	#endif
	
	/// Info
	internal static var appVersion: String {
		let base = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as? String ?? "???"
		guard let build = buildVersion, build != "1" else {
			return base
		}
		return "\(base)-\(build)"
	}
	internal static let buildVersion = Bundle.main.infoDictionary!["CFBundleVersion"] as? String
	
	/// Singleton
	internal static let `default`: PockUpdater = PockUpdater()
	
	/// Data
	internal var latestReleases: LatestReleases?
	
	/// Fetch new versions
	internal func fetchNewVersions(ignoreCache: Bool = false, _ completion: ((LatestReleases?) -> Void)?) {
		guard let latestVersionsURL = URL(string: latestVersionURLString) else {
			completion?(nil)
			return
		}
		if ignoreCache == false, let cached = self.latestReleases {
			completion?(cached)
			return
		}
		async {
			let request = URLRequest(url: latestVersionsURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60.0)
			URLSession.shared.invalidateAndCancel()
			URLSession.shared.dataTask(with: request, completionHandler: { [weak self] data, response, error in
				defer {
					URLSession.shared.finishTasksAndInvalidate()
				}
				guard let data = data, let response = try? JSONDecoder().decode(LatestReleases.self, from: data) else {
					completion?(nil)
					return
				}
				self?.latestReleases = response
				completion?(response)
			}).resume()
		}
	}
	
	/// Get new version for given widget, if any.
	internal func newVersion(for widget: WidgetInfo?) -> VersionModel? {
		guard let widget = widget, let newVersion = PockUpdater.default.latestReleases?.widgets.first(where: { $0.key.lowercased() == widget.id.lowercased() })?.value else {
			return nil
		}
		if let core_min = newVersion.core_min {
			if PockUpdater.appVersion < core_min {
				return VersionModel(version: nil, error: "A new version for this widget is available, but your version of Pock is not supported. Please, update to the minimum supported version (\(core_min)) to install this update.")
			}
		}
		return (widget.version + widget.build) < newVersion.name ? VersionModel(version: newVersion, error: nil) : nil
	}
	
}