import Testing
import SwiftUI
import Combine
import UIKit
@testable import SpeedWall_Overlay

// MARK: - Window harness

/// Hosts SwiftUI views in a dedicated key window. The app window may have
/// an alert presented (simulator without camera), which blocks first
/// responder and modal presentation.
@MainActor
enum WindowHarness {
    static func makeWindow() throws -> UIWindow {
        let scene = try #require(UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        let root = UIViewController()
        root.view.backgroundColor = .clear
        window.rootViewController = root
        window.makeKeyAndVisible()
        return window
    }

    static func tearDown(_ window: UIWindow) {
        window.isHidden = true
        window.windowScene = nil
    }

    static func spin(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    static func now() -> Double { CFAbsoluteTimeGetCurrent() }

    static func topController(_ window: UIWindow) -> UIViewController {
        var top = window.rootViewController!
        while let p = top.presentedViewController { top = p }
        return top
    }

    static func host<V: View>(_ view: V, in window: UIWindow) -> UIHostingController<V> {
        let root = window.rootViewController!
        let host = UIHostingController(rootView: view)
        host.view.backgroundColor = .clear
        host.view.frame = root.view.bounds
        root.addChild(host)
        root.view.addSubview(host.view)
        host.didMove(toParent: root)
        return host
    }

    static func unhost(_ host: UIViewController) {
        host.willMove(toParent: nil)
        host.view.removeFromSuperview()
        host.removeFromParent()
    }

    static func findView<T: UIView>(_ type: T.Type, in view: UIView) -> T? {
        if let match = view as? T { return match }
        for sub in view.subviews {
            if let found = findView(type, in: sub) { return found }
        }
        return nil
    }

    /// Waits for keyboardDidShow after `trigger` runs. Returns seconds, or nil.
    static func timeKeyboardShow(timeout: Double = 15, trigger: () -> Void) async -> Double? {
        var shown = false
        let obs = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardDidShowNotification, object: nil, queue: .main
        ) { _ in shown = true }
        defer { NotificationCenter.default.removeObserver(obs) }
        let t0 = now()
        trigger()
        let deadline = Date().addingTimeInterval(timeout)
        while !shown && Date() < deadline { await spin(0.01) }
        return shown ? now() - t0 : nil
    }
}

// MARK: - Palette presets

struct OverlayPaletteTests {
    @Test func presetsAreDistinctOpaqueSRGBColors() {
        let names = OverlayPalette.presets.map(\.name)
        #expect(!names.isEmpty)
        #expect(Set(names).count == names.count)
        for preset in OverlayPalette.presets {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            #expect(UIColor(preset.color).getRed(&r, green: &g, blue: &b, alpha: &a))
            #expect(a == 1)
        }
    }

    @Test func firstPresetIsPureWhite() throws {
        let white = try #require(OverlayPalette.presets.first)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #expect(UIColor(white.color).getRed(&r, green: &g, blue: &b, alpha: &a))
        #expect(r == 1 && g == 1 && b == 1)
    }
}

// MARK: - Measurement probe (opt-in: TEST_RUNNER_PROBE=latency)

/// Measures first-use latency of the system keyboard and color picker on
/// the current simulator. Writes /tmp/speedwall_latency.txt.
///
/// Tests execute twice per xcodebuild run in this project; only the first
/// execution in a process is cold, so only it writes results.
@MainActor
final class FocusTrigger: ObservableObject {
    @Published var focused = false
}

struct KeyboardProbeView: View {
    @ObservedObject var trigger: FocusTrigger
    @FocusState private var fieldFocused: Bool
    @State private var text = "1.0"

    var body: some View {
        VStack {
            Spacer()
            TextField("Distance", text: $text)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.decimalPad)
                .focused($fieldFocused)
                .frame(width: 100)
                .padding(30)
                .background(.regularMaterial)
                .padding()
        }
        .onReceive(trigger.$focused) { fieldFocused = $0 }
    }
}

struct PickerProbeView: View {
    @State private var color: Color = .black

    var body: some View {
        ColorPicker("", selection: $color, supportsOpacity: false)
            .labelsHidden()
            .frame(width: 32, height: 32)
    }
}

@MainActor
struct FirstUseLatencyProbe {
    private static var executions = 0

    /// Invokes UIColorWell's own presentation method (the path a tap uses).
    private func openViaWell(_ well: UIColorWell) -> Bool {
        var count: UInt32 = 0
        guard let methods = class_copyMethodList(UIColorWell.self, &count) else { return false }
        defer { free(methods) }
        for i in 0..<Int(count) {
            let name = NSStringFromSelector(method_getName(methods[i]))
            if !name.contains(":"), name.lowercased().contains("present") {
                _ = well.perform(Selector(name))
                return true
            }
        }
        return false
    }

    private func timePickerOpen(in window: UIWindow) async -> Double? {
        let host = WindowHarness.host(PickerProbeView(), in: window)
        await WindowHarness.spin(0.5)
        guard let well = WindowHarness.findView(UIColorWell.self, in: host.view),
              openViaWell(well) else {
            WindowHarness.unhost(host)
            return nil
        }
        let t0 = WindowHarness.now()
        let deadline = Date().addingTimeInterval(15)
        var presented: UIViewController?
        while Date() < deadline {
            let top = WindowHarness.topController(window)
            if top is UIColorPickerViewController, top.view.window != nil, !top.isBeingPresented {
                presented = top
                break
            }
            await WindowHarness.spin(0.01)
        }
        let total = WindowHarness.now() - t0
        presented?.dismiss(animated: false)
        await WindowHarness.spin(0.7)
        WindowHarness.unhost(host)
        await WindowHarness.spin(0.3)
        return presented == nil ? nil : total
    }

    private func timeKeyboard(in window: UIWindow) async -> Double? {
        let trigger = FocusTrigger()
        let host = WindowHarness.host(KeyboardProbeView(trigger: trigger), in: window)
        await WindowHarness.spin(0.5)
        let result = await WindowHarness.timeKeyboardShow { trigger.focused = true }
        trigger.focused = false
        await WindowHarness.spin(1.0)
        WindowHarness.unhost(host)
        await WindowHarness.spin(0.3)
        return result
    }

    private func format(_ label: String, _ seconds: Double?) -> String {
        guard let seconds = seconds else { return "\(label): not shown" }
        return String(format: "%@: %.0f ms", label, seconds * 1000)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["PROBE"] == "latency"))
    func measure() async throws {
        Self.executions += 1
        guard Self.executions == 1 else { return }
        let window = try WindowHarness.makeWindow()
        await WindowHarness.spin(1.0)
        var lines: [String] = []
        for i in 1...2 {
            lines.append(format("KEYBOARD show #\(i)", await timeKeyboard(in: window)))
        }
        for i in 1...2 {
            lines.append(format("PICKER open #\(i)", await timePickerOpen(in: window)))
        }
        try lines.joined(separator: "\n")
            .write(toFile: "/tmp/speedwall_latency.txt", atomically: true, encoding: .utf8)
        WindowHarness.tearDown(window)
    }
}


