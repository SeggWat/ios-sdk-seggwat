import SwiftUI

/// Available annotation tools.
enum AnnotationTool: String, CaseIterable, Identifiable {
    case pen
    case arrow
    case rectangle
    case text
    case blackout

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .pen: return "scribble.variable"
        case .arrow: return "arrow.up.right"
        case .rectangle: return "rectangle"
        case .text: return "textformat"
        case .blackout: return "rectangle.fill"
        }
    }

    func localizedName(language: String?) -> String {
        switch self {
        case .pen: return Localizer.string("screenshot_tool_pen", language: language)
        case .arrow: return Localizer.string("screenshot_tool_arrow", language: language)
        case .rectangle: return Localizer.string("screenshot_tool_rectangle", language: language)
        case .text: return Localizer.string("screenshot_tool_text", language: language)
        case .blackout: return Localizer.string("screenshot_tool_blackout", language: language)
        }
    }
}

/// Color presets matching the web widget's quick colors.
enum AnnotationColor: CaseIterable, Identifiable {
    case red, green, blue, yellow, magenta, black

    var id: String { "\(self)" }

    var color: Color {
        switch self {
        case .red: return .red
        case .green: return .green
        case .blue: return .blue
        case .yellow: return .yellow
        case .magenta: return Color(.magenta)
        case .black: return .black
        }
    }
}

/// A single committed (or in-progress) annotation, stored in canvas display coordinates.
struct Annotation: Identifiable {
    let id = UUID()
    var tool: AnnotationTool
    var color: AnnotationColor
    var lineWidth: CGFloat
    var points: [CGPoint] = []   // pen
    var start: CGPoint = .zero   // arrow / rectangle / blackout / text anchor
    var end: CGPoint = .zero     // arrow / rectangle / blackout
    var text: String = ""        // text
}

/// Tool + color + stroke-width selector shown beneath the canvas.
struct AnnotationToolbar: View {
    @Binding var selectedTool: AnnotationTool
    @Binding var selectedColor: AnnotationColor
    @Binding var strokeWidth: CGFloat
    @EnvironmentObject private var seggwat: SeggWat

    var body: some View {
        VStack(spacing: 14) {
            // Tools — equal width across the row
            HStack(spacing: 8) {
                ForEach(AnnotationTool.allCases) { tool in
                    toolButton(tool)
                }
            }

            // Colors — evenly distributed across the row
            HStack {
                ForEach(Array(AnnotationColor.allCases.enumerated()), id: \.element.id) { index, preset in
                    colorButton(preset)
                    if index < AnnotationColor.allCases.count - 1 {
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private func toolButton(_ tool: AnnotationTool) -> some View {
        let isSelected = selectedTool == tool
        return Button {
            selectedTool = tool
        } label: {
            VStack(spacing: 5) {
                Image(systemName: tool.systemImage)
                    .font(.system(size: 17, weight: .medium))
                Text(tool.localizedName(language: seggwat.options.language))
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .foregroundColor(isSelected ? .white : .primary)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? seggwat.options.buttonColor : Color(.systemGray5))
            )
        }
        .buttonStyle(.plain)
    }

    private func colorButton(_ preset: AnnotationColor) -> some View {
        let isSelected = selectedColor == preset
        return Button {
            selectedColor = preset
        } label: {
            Circle()
                .fill(preset.color)
                .frame(width: 30, height: 30)
                .overlay(
                    Circle().stroke(Color(.systemBackground), lineWidth: 2)
                )
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2)
                        .padding(-3)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(preset)")
    }
}
