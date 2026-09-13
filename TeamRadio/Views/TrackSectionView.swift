import MapKit
import SwiftUI

/// Circuit section: the interactive 3D track map plus key stats derived from
/// the real track geometry, with an Apple Maps mode showing the real venue.
struct TrackSectionView: View {
    let map: TrackMap
    let circuit: Circuit

    @State private var resetToken = 0
    @State private var showRealWorld = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("THE CIRCUIT")

            VStack(spacing: 0) {
                ZStack {
                    if showRealWorld, let coordinate = circuit.coordinate {
                        CircuitMapView(coordinate: coordinate)
                    } else {
                        Track3DView(map: map, resetToken: resetToken)
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
                            circleButton("arrow.counterclockwise") { resetToken += 1 }
                        }
                    }
                    .padding(10)
                }

                Text(showRealWorld
                     ? "APPLE MAPS · THE REAL VENUE"
                     : "DRAG TO ROTATE · PINCH TO ZOOM")
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
                    .shadow(color: Theme.accent.opacity(0.2), radius: 22, y: 6)
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
