//
//  SpeedWall_OverlayTests.swift
//  SpeedWall OverlayTests
//
//  Created by mk on 28.01.26.
//

import Testing
import SwiftUI
import UIKit
@testable import SpeedWall_Overlay

struct DistanceInputParsingTests {

    @Test func parsesPeriodDecimal() {
        #expect(DistanceInput.parse("1.5") == 1.5)
    }

    @Test func parsesCommaDecimal() {
        #expect(DistanceInput.parse("1,5") == 1.5)
    }

    @Test func parsesWholeNumber() {
        #expect(DistanceInput.parse("2") == 2.0)
    }

    @Test func parsesWithSurroundingWhitespace() {
        #expect(DistanceInput.parse(" 2,5 ") == 2.5)
    }

    @Test func rejectsEmptyString() {
        #expect(DistanceInput.parse("") == nil)
    }

    @Test func rejectsMultipleSeparators() {
        #expect(DistanceInput.parse("1.2.3") == nil)
        #expect(DistanceInput.parse("1,2,3") == nil)
    }

    @Test func rejectsNonFinite() {
        #expect(DistanceInput.parse("inf") == nil)
        #expect(DistanceInput.parse("nan") == nil)
    }

    @Test func rejectsZeroAndNegative() {
        #expect(DistanceInput.parse("0") == nil)
        #expect(DistanceInput.parse("-3") == nil)
    }
}

struct ColorNormalizationTests {

    @Test func grayscaleWhiteNormalizesToSRGBWhite() {
        // The picker's pure white is a 2-component grayscale-space color.
        let grayscaleWhite = Color(UIColor(white: 1.0, alpha: 1.0))
        let normalized = grayscaleWhite.normalizedToSRGB()

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #expect(UIColor(normalized).getRed(&r, green: &g, blue: &b, alpha: &a))
        #expect(abs(r - 1.0) < 0.001)
        #expect(abs(g - 1.0) < 0.001)
        #expect(abs(b - 1.0) < 0.001)
        #expect(abs(a - 1.0) < 0.001)
        #expect(UIColor(normalized).cgColor.colorSpace?.model == .rgb)
    }

    @Test func rgbColorSurvivesNormalization() {
        let orange = Color(.sRGB, red: 1.0, green: 0.655, blue: 0.149, opacity: 1.0)
        let normalized = orange.normalizedToSRGB()

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #expect(UIColor(normalized).getRed(&r, green: &g, blue: &b, alpha: &a))
        #expect(abs(r - 1.0) < 0.001)
        #expect(abs(g - 0.655) < 0.001)
        #expect(abs(b - 0.149) < 0.001)
    }
}

@MainActor
struct OverlayTintRenderingTests {

    private func averageOpaqueRGB(of image: UIImage) -> (r: Double, g: Double, b: Double, count: Int)? {
        guard let cg = image.cgImage else { return nil }
        let w = cg.width, h = cg.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                data: &data, width: w, height: h, bitsPerComponent: 8,
                bytesPerRow: w * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        var r = 0.0, g = 0.0, b = 0.0
        var n = 0
        for i in stride(from: 0, to: data.count, by: 4) {
            let a = Double(data[i + 3]) / 255
            if a > 0.5 {
                r += Double(data[i]) / 255 / a
                g += Double(data[i + 1]) / 255 / a
                b += Double(data[i + 2]) / 255 / a
                n += 1
            }
        }
        guard n > 0 else { return nil }
        return (r / Double(n), g / Double(n), b / Double(n), n)
    }

    // Mirrors OverlayView.tintedLayer. Template tinting
    // (.renderingMode(.template) + .foregroundColor) is NOT used there because
    // the live CA pipeline renders a pure white tint as the artwork's own
    // dark color; fill+mask tints correctly for every color.
    @ViewBuilder
    private func maskStyle(_ img: UIImage, tint: Color) -> some View {
        Rectangle()
            .fill(tint)
            .frame(width: 60, height: 300)
            .mask(Image(uiImage: img).resizable())
    }

    private func renderOnScreen<V: View>(_ content: V) -> UIImage? {
        let host = UIHostingController(rootView: content)
        host.view.backgroundColor = .clear
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 60, height: 300))
        window.windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first
        window.rootViewController = host
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let ui = renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        window.isHidden = true
        return ui
    }

    @Test func pickerWhiteRendersWhiteOnScreen() throws {
        let img = try #require(UIImage(named: "overlay"))
        // The picker's grid white: a 2-component grayscale-space color
        let pickerWhite = Color(UIColor(white: 1, alpha: 1))
        let rendered = try #require(renderOnScreen(maskStyle(img, tint: pickerWhite)))
        let avg = try #require(averageOpaqueRGB(of: rendered))
        #expect(avg.r > 0.95)
        #expect(avg.g > 0.95)
        #expect(avg.b > 0.95)
    }

    @Test func coloredTintRendersAccuratelyOnScreen() throws {
        let img = try #require(UIImage(named: "overlay"))
        let red = Color(.sRGB, red: 1, green: 0, blue: 0, opacity: 1)
        let rendered = try #require(renderOnScreen(maskStyle(img, tint: red)))
        let avg = try #require(averageOpaqueRGB(of: rendered))
        #expect(avg.r > 0.95)
        #expect(avg.g < 0.05)
        #expect(avg.b < 0.05)
    }
}

@MainActor
struct CalibrationStateTests {

    @Test func decimalDistanceProducesCorrectScale() {
        let state = AppState()
        state.recordCalibrationTap(at: CGPoint(x: 100, y: 100))
        state.recordCalibrationTap(at: CGPoint(x: 600, y: 100))
        state.setKnownDistance(2.5)

        #expect(state.calibrationState == .complete)
        #expect(abs(state.pixelsPerMeter - 200) < 0.001)
        #expect(state.isCalibrated)
    }

    @Test func secondTapTooCloseToFirstIsIgnored() {
        let state = AppState()
        state.recordCalibrationTap(at: CGPoint(x: 100, y: 100))
        state.recordCalibrationTap(at: CGPoint(x: 103, y: 102))

        #expect(state.secondCalibrationPoint == nil)
        if case .waitingForSecondPoint = state.calibrationState {
        } else {
            Issue.record("expected to remain in waitingForSecondPoint")
        }
    }

    @Test func nonFiniteDistanceDoesNotCompleteCalibration() {
        let state = AppState()
        state.recordCalibrationTap(at: CGPoint(x: 100, y: 100))
        state.recordCalibrationTap(at: CGPoint(x: 600, y: 100))
        state.setKnownDistance(.infinity)

        #expect(state.calibrationState != .complete)
        #expect(state.pixelsPerMeter == 0)
        #expect(!state.isCalibrated)
    }

    @Test func draggingPointsTooCloseIsRejected() {
        let state = AppState()
        state.recordCalibrationTap(at: CGPoint(x: 100, y: 100))
        state.recordCalibrationTap(at: CGPoint(x: 600, y: 100))
        state.setKnownDistance(1.0)

        state.updatePointPosition(index: 1, newPosition: CGPoint(x: 102, y: 101))

        #expect(state.secondCalibrationPoint?.screenPosition == CGPoint(x: 600, y: 100))
        #expect(abs(state.pixelsPerMeter - 500) < 0.001)
    }
}
