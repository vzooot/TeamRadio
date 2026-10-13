import Foundation

/// How this build is signed, which decides Apple's environments: a
/// development-signed build (from Xcode, Debug or Release) talks to
/// CloudKit's Development database and gets sandbox push tokens; TestFlight
/// and the App Store use Production for both.
enum BuildSigning {
    static let isDevelopment: Bool = {
        #if targetEnvironment(simulator)
        #if DEBUG
        return true
        #else
        return false
        #endif
        #else
        // Only development and ad-hoc builds carry a provisioning profile;
        // development ones allow a debugger (get-task-allow).
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .isoLatin1) else { return false }
        return text.range(of: "<key>get-task-allow</key>\\s*<true/>", options: .regularExpression) != nil
        #endif
    }()
}
