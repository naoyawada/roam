#!/usr/bin/env swift

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let size: CGFloat = 1024
let gridSize: CGFloat = 4
let padding: CGFloat = size * 0.11
let gap: CGFloat = size * 0.04
let cellSize = (size - padding * 2 - gap * (gridSize - 1)) / gridSize
let cornerRadius: CGFloat = cellSize * 0.22

struct CellSpec {
    let color: (CGFloat, CGFloat, CGFloat)  // RGB
    let opacity: CGFloat
    let isFilled: Bool
}

// City fade pattern — matches the hero from city-fade-combo.html
let lightCells: [[CellSpec]] = [
    // Row 1: full opacity
    [.init(color: (0.478, 0.361, 0.267), opacity: 1.0, isFilled: true),    // leather
     .init(color: (0.369, 0.490, 0.431), opacity: 1.0, isFilled: true),    // sage
     .init(color: (0.604, 0.494, 0.392), opacity: 1.0, isFilled: true),    // tan
     .init(color: (0.545, 0.420, 0.353), opacity: 1.0, isFilled: true)],   // umber
    // Row 2: slightly faded
    [.init(color: (0.369, 0.490, 0.431), opacity: 0.82, isFilled: true),
     .init(color: (0.690, 0.604, 0.525), opacity: 0.82, isFilled: true),   // sand
     .init(color: (0.478, 0.361, 0.267), opacity: 0.75, isFilled: true),
     .init(color: (0.369, 0.490, 0.431), opacity: 0.65, isFilled: true)],
    // Row 3: more faded
    [.init(color: (0.604, 0.494, 0.392), opacity: 0.55, isFilled: true),
     .init(color: (0.478, 0.361, 0.267), opacity: 0.40, isFilled: true),
     .init(color: (0.369, 0.490, 0.431), opacity: 0.25, isFilled: true),
     .init(color: (0, 0, 0), opacity: 0, isFilled: false)],
    // Row 4: mostly empty
    [.init(color: (0.690, 0.604, 0.525), opacity: 0.20, isFilled: true),
     .init(color: (0, 0, 0), opacity: 0, isFilled: false),
     .init(color: (0, 0, 0), opacity: 0, isFilled: false),
     .init(color: (0, 0, 0), opacity: 0, isFilled: false)],
]

let darkCells: [[CellSpec]] = [
    // Row 1: full opacity with dark accent
    [.init(color: (0.698, 0.565, 0.459), opacity: 1.0, isFilled: true),    // #B29075
     .init(color: (0.369, 0.490, 0.431), opacity: 1.0, isFilled: true),
     .init(color: (0.604, 0.494, 0.392), opacity: 1.0, isFilled: true),
     .init(color: (0.545, 0.420, 0.353), opacity: 1.0, isFilled: true)],
    // Row 2
    [.init(color: (0.369, 0.490, 0.431), opacity: 0.82, isFilled: true),
     .init(color: (0.690, 0.604, 0.525), opacity: 0.82, isFilled: true),
     .init(color: (0.698, 0.565, 0.459), opacity: 0.75, isFilled: true),
     .init(color: (0.369, 0.490, 0.431), opacity: 0.65, isFilled: true)],
    // Row 3
    [.init(color: (0.604, 0.494, 0.392), opacity: 0.55, isFilled: true),
     .init(color: (0.698, 0.565, 0.459), opacity: 0.40, isFilled: true),
     .init(color: (0.369, 0.490, 0.431), opacity: 0.25, isFilled: true),
     .init(color: (0, 0, 0), opacity: 0, isFilled: false)],
    // Row 4
    [.init(color: (0.690, 0.604, 0.525), opacity: 0.20, isFilled: true),
     .init(color: (0, 0, 0), opacity: 0, isFilled: false),
     .init(color: (0, 0, 0), opacity: 0, isFilled: false),
     .init(color: (0, 0, 0), opacity: 0, isFilled: false)],
]

func addRoundedRect(to ctx: CGContext, rect: CGRect, radius: CGFloat) {
    let path = CGMutablePath()
    path.addRoundedRect(in: rect, cornerWidth: radius, cornerHeight: radius)
    ctx.addPath(path)
}

func renderIcon(
    cells: [[CellSpec]],
    bgR: CGFloat, bgG: CGFloat, bgB: CGFloat,
    strokeR: CGFloat, strokeG: CGFloat, strokeB: CGFloat, strokeAlphaBase: CGFloat,
    outputPath: String
) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: Int(size),
        height: Int(size),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        print("Failed to create context")
        return
    }

    // Background
    ctx.setFillColor(CGColor(red: bgR, green: bgG, blue: bgB, alpha: 1.0))
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

    // Draw grid
    for row in 0..<4 {
        for col in 0..<4 {
            let cell = cells[row][col]
            // Flip Y for CoreGraphics (origin at bottom-left)
            let x = padding + CGFloat(col) * (cellSize + gap)
            let y = padding + CGFloat(row) * (cellSize + gap)
            let flippedY = size - y - cellSize
            let rect = CGRect(x: x, y: flippedY, width: cellSize, height: cellSize)

            if cell.isFilled {
                ctx.saveGState()
                ctx.setAlpha(cell.opacity)
                ctx.setFillColor(CGColor(
                    red: cell.color.0,
                    green: cell.color.1,
                    blue: cell.color.2,
                    alpha: 1.0
                ))
                addRoundedRect(to: ctx, rect: rect, radius: cornerRadius)
                ctx.fillPath()
                ctx.restoreGState()
            } else {
                // Empty cell — thin stroke
                let alphaFade: CGFloat = row == 3 && col == 3 ? 0.04 :
                                         row == 3 && col == 2 ? 0.06 : 0.08
                ctx.saveGState()
                ctx.setStrokeColor(CGColor(
                    red: strokeR, green: strokeG, blue: strokeB,
                    alpha: strokeAlphaBase * alphaFade / 0.08
                ))
                ctx.setLineWidth(size * 0.003)
                addRoundedRect(to: ctx, rect: rect.insetBy(dx: 1, dy: 1), radius: cornerRadius)
                ctx.strokePath()
                ctx.restoreGState()
            }
        }
    }

    guard let image = ctx.makeImage() else {
        print("Failed to make image")
        return
    }

    let url = URL(fileURLWithPath: outputPath)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        print("Failed to create destination")
        return
    }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    print("Saved: \(outputPath)")
}

let basePath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

// Light icon
renderIcon(
    cells: lightCells,
    bgR: 0.969, bgG: 0.969, bgB: 0.957,
    strokeR: 0.149, strokeG: 0.145, strokeB: 0.118, strokeAlphaBase: 0.08,
    outputPath: "\(basePath)/icon-light.png"
)

// Dark icon
renderIcon(
    cells: darkCells,
    bgR: 0.098, bgG: 0.094, bgB: 0.086,
    strokeR: 0.910, strokeG: 0.902, strokeB: 0.878, strokeAlphaBase: 0.10,
    outputPath: "\(basePath)/icon-dark.png"
)
