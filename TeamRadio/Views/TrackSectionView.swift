import MapKit
import SwiftUI

/// Circuit section: the interactive 3D track map plus key stats derived from
/// the real track geometry, with an Apple Maps mode showing the real venue.
struct TrackSectionView: View {
    let map: TrackMap
    let circuit: Circuit

    @State private var resetToken = 0
    @State private var showRealWorld = false
    @State private var guide: CircuitGuide?
    @State private var selectedCorner: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("THE CIRCUIT")
                .task(id: circuit.circuitId) {
                    guard GameFeature.isEnabled else { return }
                    guide = await GuideService.guide(circuitId: circuit.circuitId, corners: map.corners.count)
                }

            VStack(spacing: 0) {
                ZStack {
                    if showRealWorld, let coordinate = circuit.coordinate {
                        CircuitMapView(coordinate: coordinate)
                    } else {
                        Track3DView(map: map, resetToken: resetToken, selectedCorner: selectedCorner) { number in
                            withAnimation(.easeOut(duration: 0.2)) { selectedCorner = number }
                        }
                    }
                }
                .frame(height: 300)
                .overlay(alignment: .topTrailing) {
                    HStack(spacing: 8) {
                        if circuit.coordinate != nil {
                            circleButton(showRealWorld ? "cube" : "globe.europe.africa.fill") {
                                showRealWorld.toggle()
                            }
                        }
                        if !showRealWorld {
                            circleButton("arrow.counterclockwise") {
                                selectedCorner = nil
                                resetToken += 1
                            }
                        }
                    }
                    .padding(10)
                }

                Text(showRealWorld
                     ? "APPLE MAPS · THE REAL VENUE"
                     : "DRAG · PINCH · TAP A TURN TO ZOOM IN")
                    .font(.f1(10, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(Theme.faintText)
                    .padding(.bottom, 12)

                HStack(spacing: 8) {
                    statChip(String(format: "%.2f KM", map.lengthKm), "LENGTH")
                    if !map.corners.isEmpty {
                        statChip("\(map.corners.count)", "CORNERS")
                    }
                    statChip(map.isClockwise ? "CW ↻" : "ACW ↺", "DIRECTION")
                    if let pitLoss = map.pitLossSeconds {
                        statChip(String(format: "%.0fS", pitLoss), "PIT LOSS")
                    }
                    if let gain = map.elevationGainM {
                        statChip(String(format: "%.0F M", gain), "ELEVATION")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)

                if let guide, !guide.corners.isEmpty {
                    cornerGuide(guide)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Theme.card, Color.black.opacity(0.7)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Theme.glassStroke, lineWidth: 1)
                    )
                    .trioGlow(cornerRadius: 20)
            )

            if let wiki = URL(string: circuit.url ?? "") {
                Link(destination: wiki) {
                    HStack(spacing: 4) {
                        Text("Circuit details on Wikipedia")
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
                }
                .padding(.leading, 4)
            }
        }
    }

    /// Corner chips under the track; the selected corner glows on the map and
    /// its line shows below.
    private func cornerGuide(_ guide: CircuitGuide) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CORNER GUIDE · TAP A CORNER")
                .font(.f1(10, weight: .bold))
                .tracking(3)
                .foregroundStyle(Theme.faintText)
                .padding(.horizontal, 14)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(guide.corners) { corner in
                            let on = corner.number == selectedCorner
                            Button {
                                withAnimation(.easeOut(duration: 0.2)) { selectedCorner = on ? nil : corner.number }
                            } label: {
                                Text("T\(corner.number)")
                                    .font(.f1(13))
                                    .foregroundStyle(on ? Theme.onAccent : .white)
                                    .frame(minWidth: 40)
                                    .padding(.vertical, 7)
                                    .background(Capsule().fill(on ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Color.white.opacity(0.06))))
                                    .overlay(Capsule().strokeBorder(on ? Color.clear : Color.white.opacity(0.1)))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Turn \(corner.number)")
                            .id(corner.number)
                        }
                    }
                    .padding(.horizontal, 14)
                }
                // A turn tapped on the map scrolls its chip into view.
                .onChange(of: selectedCorner) { _, number in
                    guard let number else { return }
                    withAnimation { proxy.scrollTo(number, anchor: .center) }
                }
            }
            if let corner = guide.corner(selectedCorner) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(corner.name.isEmpty ? "TURN \(corner.number)" : "TURN \(corner.number) · \(corner.name.uppercased())")
                        .font(.f1(15).italic())
                        .foregroundStyle(Theme.accent)
                    Text(corner.text)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                    if !corner.moment.isEmpty {
                        Text(corner.moment)
                            .font(.system(size: 13).italic())
                            .foregroundStyle(Theme.dimText)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accent.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.accent.opacity(0.3)))
                .padding(.horizontal, 14)
                .transition(.opacity)
            }
        }
        .padding(.bottom, 14)
        .task(id: circuit.circuitId) {
            selectedCorner = nil
            #if DEBUG
            // -FocusCorner N: select a turn after launch, for screenshots
            let n = UserDefaults.standard.integer(forKey: "FocusCorner")
            if n > 0 {
                try? await Task.sleep(for: .seconds(6))
                selectedCorner = n
            }
            #endif
        }
    }

    private func statChip(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.f1Digits(17))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.f1(10, weight: .bold))
                .tracking(1)
                .foregroundStyle(Theme.dimText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Theme.glassStroke, lineWidth: 1)
                )
        )
    }

    private func circleButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.dimText)
                .padding(9)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .overlay(Circle().strokeBorder(Theme.glassStroke, lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }
}

/// Apple Maps over the real venue — a pitched 3D camera on the circuit,
/// with Apple's detailed racetrack models where they exist.
struct CircuitMapView: View {
    let coordinate: CLLocationCoordinate2D

    var body: some View {
        Map(initialPosition: .camera(
            MapCamera(centerCoordinate: coordinate, distance: 2800, heading: 40, pitch: 62)
        ))
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        .mapControlVisibility(.hidden)
    }
}

private extension Circuit {
    /// Circuit coordinates as reported by the schedule API.
    var coordinate: CLLocationCoordinate2D? {
        guard let latText = location.lat, let lonText = location.long,
              let lat = Double(latText), let lon = Double(lonText) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}
