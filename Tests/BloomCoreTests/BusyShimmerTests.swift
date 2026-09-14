import Foundation
import Testing
@testable import BloomCore

/// The band of light that passes through a busy name. The owner chose it off a mockup, so these
/// are that mockup's numbers, and the three properties a moving band has to have to look like one.
@Suite("The busy shimmer")
struct BusyShimmerTests {
    /// The band enters from nothing and leaves to nothing, so the moment the crossing wraps round
    /// is a moment nobody can see. A band still touching the text at either end would jump.
    @Test("the band is wholly off the text at both ends of a crossing")
    func wrapsOffTheText() {
        let atStart = BusyShimmer.bandCentre(atPhase: 0)
        let atEnd = BusyShimmer.bandCentre(atPhase: 1)
        #expect(atStart + BusyShimmer.rampWidth <= 0)
        #expect(atEnd - BusyShimmer.rampWidth >= 1)
        #expect(BusyShimmer.gradientSpan(atPhase: 1).lowerBound == 0)
        #expect(BusyShimmer.gradientSpan(atPhase: 0).upperBound == 1)
    }

    @Test("it crosses from the leading edge to the trailing one, at a steady speed")
    func travelsLeadingToTrailing() {
        let quarters = [0.0, 0.25, 0.5, 0.75, 1].map(BusyShimmer.bandCentre(atPhase:))
        let steps = zip(quarters.dropFirst(), quarters).map { $0 - $1 }
        #expect(steps.allSatisfy { $0 > 0 })
        #expect(steps.allSatisfy { abs($0 - steps[0]) < 1e-9 })
        #expect(abs(BusyShimmer.bandCentre(atPhase: 0.5) - 0.5) < 1e-9)
    }

    /// Two tabs that went busy at different moments are at the same point in their crossings,
    /// which is what an absolute clock buys and a per view animation cannot.
    @Test("every busy name is in step, whenever it started")
    func inStep() {
        let now = 812_345.6
        // Within a nanosecond's worth of phase: a clock at 800,000 seconds keeps about ten digits.
        #expect(abs(BusyShimmer.phase(at: now) - BusyShimmer.phase(at: now + BusyShimmer.period * 7)) < 1e-9)
        #expect(BusyShimmer.phase(at: 0) == 0)
        #expect(BusyShimmer.phase(at: -0.6) > 0)
        for time in stride(from: -5.0, through: 5, by: 0.37) {
            let phase = BusyShimmer.phase(at: time)
            #expect(phase >= 0 && phase < 1)
        }
    }

    /// The reason thirty frames a second is enough for a SwiftUI driven band.
    @Test("a frame moves the band less than a tenth of its soft edge")
    func stepsInvisibly() {
        #expect(BusyShimmer.stepShareOfRamp < 0.1)
    }

    @Test("the mockup's gradient: ink to 40 per cent, lit at 50, ink from 60")
    func mockupGradient() {
        #expect(BusyShimmer.span == 3)
        #expect(abs(BusyShimmer.bandCentre - BusyShimmer.bandHalfWidth - 0.4) < 1e-9)
        #expect(abs(BusyShimmer.bandCentre + BusyShimmer.bandHalfWidth - 0.6) < 1e-9)
        #expect(BusyShimmer.period == 2.4)
    }

    // MARK: Arriving and leaving

    @Test("a turn that starts fades the band in, and one that stops fades it out")
    func fadesBothWays() {
        let arriving = BusyShimmer.Fade.toward(isActive: true, from: nil, at: 10)
        #expect(arriving.strength(at: 10) == 0)
        #expect(arriving.strength(at: 10 + BusyShimmer.fade) == 1)
        #expect(!arriving.isLeaving)

        let leaving = BusyShimmer.Fade.toward(isActive: false, from: arriving, at: 20)
        #expect(leaving.strength(at: 20) == 1)
        #expect(abs(leaving.strength(at: leaving.endsAt)) < 1e-9)
        #expect(leaving.strength(at: leaving.endsAt + 5) == 0)
        #expect(leaving.isLeaving)
    }

    /// Stopping mid arrival must not flash the band to full before it goes.
    @Test("reversing mid fade carries on from the strength it had reached")
    func reversesWithoutAJump() {
        let arriving = BusyShimmer.Fade.toward(isActive: true, from: nil, at: 0)
        let midway = BusyShimmer.fade / 2
        let reached = arriving.strength(at: midway)
        let leaving = BusyShimmer.Fade.toward(isActive: false, from: arriving, at: midway)
        #expect(abs(leaving.strength(at: midway) - reached) < 1e-9)
        #expect(leaving.strength(at: midway + 0.01) < reached)
    }

    @Test("a name that appears already busy is lit from its first frame")
    func presentIsLit() {
        let present = BusyShimmer.Fade.present(at: 3)
        #expect(present.strength(at: 3) == 1)
        #expect(!present.isLeaving)
    }
}
