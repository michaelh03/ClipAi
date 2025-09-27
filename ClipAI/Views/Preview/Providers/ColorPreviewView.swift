import SwiftUI

/// Clean color preview
struct ColorPreviewView: View {
    /// The clipboard item containing color data
    let item: ClipItem

    /// Parsed color information
    @State private var colorInfo: ColorInfo?

    /// Size of the main color swatch
    private let swatchSize: CGFloat = 120

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                colorSwatchView
                colorDetailsView
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            parseColorFromContent()
        }
    }
    
    /// Main color swatch display
    private var colorSwatchView: some View {
        VStack(spacing: 16) {
            // Color swatch
            RoundedRectangle(cornerRadius: 12)
                .fill(colorInfo?.color ?? Color.clear)
                .frame(width: swatchSize, height: swatchSize)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)

            // Original format
            Text(item.content)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial)
                .cornerRadius(8)
        }
    }
    
    /// Detailed color information
    private var colorDetailsView: some View {
        Group {
            if let colorInfo = colorInfo {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], alignment: .leading, spacing: 12) {
                    colorFormatItem("Hex", value: colorInfo.hexValue)
                    colorFormatItem("RGB", value: colorInfo.rgbValue)
                    colorFormatItem("HSL", value: colorInfo.hslValue)
                    colorFormatItem("Brightness", value: String(format: "%.1f%%", colorInfo.brightness * 100))
                }
            } else {
                EmptyView()
            }
        }
    }
    
    /// Individual color format item
    private func colorFormatItem(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.regularMaterial)
                .cornerRadius(6)
        }
    }
    
    /// Parse color information from the clipboard content
    private func parseColorFromContent() {
        colorInfo = ColorInfo.parse(from: item.content)
    }
}

// MARK: - Color Information Model

struct ColorInfo {
    let color: Color
    let hexValue: String
    let rgbValue: String
    let hslValue: String
    let brightness: Double
    let hasAlpha: Bool
    
    var brightnessCategory: String {
        switch brightness {
        case 0.0..<0.2:
            return "Very Dark"
        case 0.2..<0.4:
            return "Dark"
        case 0.4..<0.6:
            return "Medium"
        case 0.6..<0.8:
            return "Light"
        default:
            return "Very Light"
        }
    }
    
    var description: String {
        return "Color: \(hexValue), Brightness: \(brightnessCategory)"
    }
    
    static func parse(from content: String) -> ColorInfo? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try different parsing methods
        if let nsColor = parseHexColor(trimmed) ?? parseRGBColor(trimmed) ?? parseHSLColor(trimmed) ?? parseCSSColor(trimmed) {
            let color = Color(nsColor)
            
            // Extract RGB components for calculations
            let rgb = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            rgb.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            
            // Calculate brightness (perceived luminance)
            let brightness = 0.299 * red + 0.587 * green + 0.114 * blue
            
            // Generate different format representations
            let hexValue = String(format: "#%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
            let rgbValue = alpha < 1.0 ? 
                String(format: "rgba(%.0f, %.0f, %.0f, %.2f)", red * 255, green * 255, blue * 255, alpha) :
                String(format: "rgb(%.0f, %.0f, %.0f)", red * 255, green * 255, blue * 255)
            
            // Convert to HSL
            let hsl = rgbToHSL(red: red, green: green, blue: blue)
            let hslValue = alpha < 1.0 ?
                String(format: "hsla(%.0f, %.0f%%, %.0f%%, %.2f)", hsl.h, hsl.s * 100, hsl.l * 100, alpha) :
                String(format: "hsl(%.0f, %.0f%%, %.0f%%)", hsl.h, hsl.s * 100, hsl.l * 100)
            
            return ColorInfo(
                color: color,
                hexValue: hexValue,
                rgbValue: rgbValue,
                hslValue: hslValue,
                brightness: brightness,
                hasAlpha: alpha < 1.0
            )
        }
        
        return nil
    }
    
    // MARK: - Color Parsing Methods
    
    private static func parseHexColor(_ string: String) -> NSColor? {
        var hex = string
        if hex.hasPrefix("#") {
            hex = String(hex.dropFirst())
        }
        
        guard hex.count == 3 || hex.count == 6 || hex.count == 8 else { return nil }
        
        // Expand 3-digit hex to 6-digit
        if hex.count == 3 {
            hex = hex.map { "\($0)\($0)" }.joined()
        }
        
        guard let value = UInt32(hex, radix: 16) else { return nil }
        
        let red, green, blue, alpha: CGFloat
        
        if hex.count == 8 {
            red = CGFloat((value & 0xFF000000) >> 24) / 255.0
            green = CGFloat((value & 0x00FF0000) >> 16) / 255.0
            blue = CGFloat((value & 0x0000FF00) >> 8) / 255.0
            alpha = CGFloat(value & 0x000000FF) / 255.0
        } else {
            red = CGFloat((value & 0xFF0000) >> 16) / 255.0
            green = CGFloat((value & 0x00FF00) >> 8) / 255.0
            blue = CGFloat(value & 0x0000FF) / 255.0
            alpha = 1.0
        }
        
        return NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    private static func parseRGBColor(_ string: String) -> NSColor? {
        // Match rgb(r,g,b) or rgba(r,g,b,a)
        let pattern = #"rgba?\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*(?:,\s*([0-9.]+))?\s*\)"#
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        
        guard let match = regex?.firstMatch(in: string, range: NSRange(location: 0, length: string.count)) else {
            return nil
        }
        
        let redStr = (string as NSString).substring(with: match.range(at: 1))
        let greenStr = (string as NSString).substring(with: match.range(at: 2))
        let blueStr = (string as NSString).substring(with: match.range(at: 3))
        
        guard let red = Int(redStr), let green = Int(greenStr), let blue = Int(blueStr),
              red <= 255, green <= 255, blue <= 255 else { return nil }
        
        var alpha: Double = 1.0
        if match.range(at: 4).location != NSNotFound {
            let alphaStr = (string as NSString).substring(with: match.range(at: 4))
            alpha = Double(alphaStr) ?? 1.0
        }
        
        return NSColor(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: alpha)
    }
    
    private static func parseHSLColor(_ string: String) -> NSColor? {
        // Match hsl(h,s%,l%) or hsla(h,s%,l%,a)
        let pattern = #"hsla?\(\s*(\d{1,3})\s*,\s*(\d{1,3})%\s*,\s*(\d{1,3})%\s*(?:,\s*([0-9.]+))?\s*\)"#
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        
        guard let match = regex?.firstMatch(in: string, range: NSRange(location: 0, length: string.count)) else {
            return nil
        }
        
        let hueStr = (string as NSString).substring(with: match.range(at: 1))
        let satStr = (string as NSString).substring(with: match.range(at: 2))
        let lightStr = (string as NSString).substring(with: match.range(at: 3))
        
        guard let hue = Int(hueStr), let sat = Int(satStr), let light = Int(lightStr),
              hue <= 360, sat <= 100, light <= 100 else { return nil }
        
        var alpha: Double = 1.0
        if match.range(at: 4).location != NSNotFound {
            let alphaStr = (string as NSString).substring(with: match.range(at: 4))  
            alpha = Double(alphaStr) ?? 1.0
        }
        
        // Convert HSL to RGB
        let rgb = hslToRGB(h: Double(hue), s: Double(sat) / 100.0, l: Double(light) / 100.0)
        return NSColor(red: rgb.r, green: rgb.g, blue: rgb.b, alpha: alpha)
    }
    
    private static func parseCSSColor(_ string: String) -> NSColor? {
        let lowercased = string.lowercased()
        let cssColors: [String: NSColor] = [
            "red": NSColor.red,
            "blue": NSColor.blue,
            "green": NSColor.green,
            "yellow": NSColor.yellow,
            "orange": NSColor.orange,
            "purple": NSColor.purple,
            "pink": NSColor.systemPink,
            "brown": NSColor.brown,
            "black": NSColor.black,
            "white": NSColor.white,
            "gray": NSColor.gray,
            "grey": NSColor.gray
        ]
        
        return cssColors[lowercased]
    }
    
    // MARK: - Color Space Conversion Helpers
    
    private static func rgbToHSL(red: CGFloat, green: CGFloat, blue: CGFloat) -> (h: Double, s: Double, l: Double) {
        let max = Swift.max(red, green, blue)
        let min = Swift.min(red, green, blue)
        let delta = max - min
        
        let lightness = (max + min) / 2
        
        guard delta > 0 else {
            return (0, 0, Double(lightness))
        }
        
        let saturation = lightness > 0.5 ? delta / (2 - max - min) : delta / (max + min)
        
        let hue: CGFloat
        switch max {
        case red:
            hue = ((green - blue) / delta) + (green < blue ? 6 : 0)
        case green:
            hue = (blue - red) / delta + 2
        case blue:
            hue = (red - green) / delta + 4
        default:
            hue = 0
        }
        
        return (Double(hue * 60), Double(saturation), Double(lightness))
    }
    
    private static func hslToRGB(h: Double, s: Double, l: Double) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let c = (1 - abs(2 * l - 1)) * s
        let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = l - c / 2
        
        let (r1, g1, b1): (Double, Double, Double)
        
        switch h {
        case 0..<60:
            (r1, g1, b1) = (c, x, 0)
        case 60..<120:
            (r1, g1, b1) = (x, c, 0)
        case 120..<180:
            (r1, g1, b1) = (0, c, x)
        case 180..<240:
            (r1, g1, b1) = (0, x, c)
        case 240..<300:
            (r1, g1, b1) = (x, 0, c)
        default:
            (r1, g1, b1) = (c, 0, x)
        }
        
        return (CGFloat(r1 + m), CGFloat(g1 + m), CGFloat(b1 + m))
    }
}

// MARK: - Preview Support
#Preview("Hex Color") {
    let hexItem = ClipItem(content: "#FF5733")
    ColorPreviewView(item: hexItem)
        .frame(width: 350, height: 500)
}

#Preview("RGB Color") {
    let rgbItem = ClipItem(content: "rgb(255, 87, 51)")
    ColorPreviewView(item: rgbItem)
        .frame(width: 350, height: 500)
}

#Preview("RGBA Color") {
    let rgbaItem = ClipItem(content: "rgba(255, 87, 51, 0.8)")
    ColorPreviewView(item: rgbaItem)
        .frame(width: 350, height: 500)
}

#Preview("HSL Color") {
    let hslItem = ClipItem(content: "hsl(14, 100%, 60%)")
    ColorPreviewView(item: hslItem)
        .frame(width: 350, height: 500)
}

#Preview("CSS Color") {
    let cssItem = ClipItem(content: "red")
    ColorPreviewView(item: cssItem)
        .frame(width: 350, height: 500)
}