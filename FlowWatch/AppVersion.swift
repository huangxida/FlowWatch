//
//  AppVersion.swift
//  FlowWatch
//
//  Created by xida huang on 1/22/26.
//

import Foundation

enum AppVersion {
    static var shortVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    static var displayString: String {
        "\(shortVersion) (\(buildNumber))"
    }
}
