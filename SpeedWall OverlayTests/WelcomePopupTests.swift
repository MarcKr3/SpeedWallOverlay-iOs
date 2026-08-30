import Testing
import SwiftUI
import UIKit
@testable import SpeedWall_Overlay

// MARK: - Welcome popup persistence

@MainActor
struct WelcomePopupTests {

    /// An empty UserDefaults suite. Callers remove it with `removePersistentDomain`.
    private static func makeSuite() throws -> (defaults: UserDefaults, name: String) {
        let name = "WelcomePopupTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return (defaults, name)
    }

    @Test func showsOnFirstLaunch() throws {
        let (defaults, name) = try Self.makeSuite()
        defer { defaults.removePersistentDomain(forName: name) }

        #expect(AppState(defaults: defaults).showWelcome)
    }

    @Test func closeWithoutCheckboxShowsAgainOnNextLaunch() throws {
        let (defaults, name) = try Self.makeSuite()
        defer { defaults.removePersistentDomain(forName: name) }

        let state = AppState(defaults: defaults)
        state.dismissWelcome(dontShowAgain: false)

        #expect(!state.showWelcome)
        #expect(AppState(defaults: defaults).showWelcome)
    }

    @Test func dontShowAgainSuppressesNextLaunch() throws {
        let (defaults, name) = try Self.makeSuite()
        defer { defaults.removePersistentDomain(forName: name) }

        let state = AppState(defaults: defaults)
        state.dismissWelcome(dontShowAgain: true)

        #expect(!state.showWelcome)
        #expect(!AppState(defaults: defaults).showWelcome)
        #expect(defaults.bool(forKey: AppState.hideWelcomeKey))
    }
}

// MARK: - Shared info card content

struct InfoCardContentTests {

    @Test func versionComesFromBundle() throws {
        let bundleVersion = try #require(
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        )
        #expect(AppVersion.marketing == bundleVersion)
        #expect(AppVersion.marketing.range(of: #"^\d+(\.\d+)+$"#, options: .regularExpression) != nil)
    }

    @Test func staccatoLinkIsHTTPS() {
        #expect(StaccatoLink.url.scheme == "https")
        #expect(StaccatoLink.url.host == "staccato.run")
    }

    @Test func promoImageIsBundled() {
        #expect(UIImage(named: "og-image") != nil)
    }
}
