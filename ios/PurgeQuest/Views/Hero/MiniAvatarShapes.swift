//
//  MiniAvatarShapes.swift
//  PurgeQuest
//
//  Silhouette paths for the chunky-cartoon hero figure. Every shape is a
//  closed path so the cel system can fill it in three hard tones and stroke
//  one thick outline around it.
//

import SwiftUI

/// Trapezoid panel: wider at the bottom for a sturdy chibi stance.
struct TaperedShape: Shape {
    var topWidth: CGFloat
    var bottomWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        let topInset = rect.width * (1 - topWidth) / 2
        let bottomInset = rect.width * (1 - bottomWidth) / 2
        return Path { p in
            p.move(to: CGPoint(x: rect.minX + topInset, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX - topInset, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX - bottomInset, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX + bottomInset, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

/// Panel with a tattered zigzag hem, used for the wraith cloak.
struct NotchShape: Shape {
    var topWidth: CGFloat = 0.86

    func path(in rect: CGRect) -> Path {
        let topInset = rect.width * (1 - topWidth) / 2
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + topInset, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - topInset, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.1))
        let teeth = 4
        let step = rect.width / CGFloat(teeth)
        for i in stride(from: teeth - 1, through: 0, by: -1) {
            let x = rect.minX + step * CGFloat(i) + step / 2
            let depth: CGFloat = i % 2 == 0 ? rect.maxY : rect.maxY - rect.height * 0.22
            p.addLine(to: CGPoint(x: x, y: depth))
        }
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.1))
        p.closeSubpath()
        return p
    }
}

/// Rhombus, used for knee guards, gems, and sparks.
struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            p.closeSubpath()
        }
    }
}

/// Triangle with the point up, used for hat cones, ears, and mace spikes.
struct ConeShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

/// Rounded scale plate, used for dragonhide shoulder armor.
struct ScaleShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.midY),
                control: CGPoint(x: rect.midX, y: rect.minY)
            )
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

/// Thick V band pointing down, used for emblems and engravings.
struct ChevronShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.55))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY * 0.55))
            p.closeSubpath()
        }
    }
}

/// Helmet face opening: rounded top, wider rounded bottom.
struct FaceWindowShape: Shape {
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = rect.height * 0.30
        return Path { p in
            p.move(to: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.minY))
            p.addQuadCurve(
                to: CGPoint(x: rect.maxX - rect.width * 0.10, y: rect.minY),
                control: CGPoint(x: rect.midX, y: rect.minY - r * 0.6)
            )
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
            p.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - r),
                control: CGPoint(x: rect.midX, y: rect.maxY + r * 0.4)
            )
            p.closeSubpath()
        }
    }
}

/// Crest fin for the Dragoncrest helm, leaning to one side.
struct FinShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.maxY))
            p.addQuadCurve(
                to: CGPoint(x: rect.midX, y: rect.minY),
                control: CGPoint(x: rect.minX - rect.width * 0.05, y: rect.minY + rect.height * 0.25)
            )
            p.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY),
                control: CGPoint(x: rect.maxX - rect.width * 0.15, y: rect.minY + rect.height * 0.35)
            )
            p.closeSubpath()
        }
    }
}

/// Pointed petal lobe, used for the knight's twin gold crest.
struct CrestLobeShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addQuadCurve(
                to: CGPoint(x: rect.midX, y: rect.maxY),
                control: CGPoint(x: rect.minX + rect.width * 0.05, y: rect.midY)
            )
            p.addQuadCurve(
                to: CGPoint(x: rect.midX, y: rect.minY),
                control: CGPoint(x: rect.maxX - rect.width * 0.05, y: rect.midY)
            )
            p.closeSubpath()
        }
    }
}

/// Sword blade with a triangular tip pointing up.
struct BladeShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.minY + rect.height * 0.30))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.16, y: rect.minY + rect.height * 0.30))
            p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.16, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

/// Classic heater shield: curved top, tapering to a rounded point.
struct HeaterShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.14))
            p.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.14),
                control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.12)
            )
            p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.06, y: rect.minY + rect.height * 0.45))
            p.addQuadCurve(
                to: CGPoint(x: rect.midX, y: rect.maxY),
                control: CGPoint(x: rect.maxX - rect.width * 0.28, y: rect.maxY - rect.height * 0.22)
            )
            p.addQuadCurve(
                to: CGPoint(x: rect.minX + rect.width * 0.06, y: rect.minY + rect.height * 0.45),
                control: CGPoint(x: rect.minX + rect.width * 0.28, y: rect.maxY - rect.height * 0.22)
            )
            p.closeSubpath()
        }
    }
}

/// Ghostly teardrop with a wavy bottom edge.
struct WispShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY * 0.7),
                control: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.25)
            )
            p.addQuadCurve(
                to: CGPoint(x: rect.midX, y: rect.maxY * 0.8),
                control: CGPoint(x: rect.midX + rect.width * 0.2, y: rect.maxY)
            )
            p.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY * 0.7),
                control: CGPoint(x: rect.midX - rect.width * 0.2, y: rect.maxY)
            )
            p.addQuadCurve(
                to: CGPoint(x: rect.midX, y: rect.minY),
                control: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.25)
            )
            p.closeSubpath()
        }
    }
}
