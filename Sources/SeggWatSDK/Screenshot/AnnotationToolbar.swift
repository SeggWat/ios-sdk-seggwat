import SwiftUI
import PencilKit

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
        case .pen: return "pencil.tip"
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

    var id: String { color.description }

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

    var uiColor: UIColor {
        switch self {
        case .red: return .red
        case .green: return .green
        case .blue: return .blue
        case .yellow: return .yellow
        case .magenta: return .magenta
        case .black: return .black
        }
    }
}

/// Toolbar for selecting annotation tools and colors.
struct AnnotationToolbar: View {
    @Binding var selectedTool: AnnotationTool
    @Binding var selectedColor: AnnotationColor
    @Binding var strokeWidth: CGFloat
    @EnvironmentObject private var seggwat: SeggWat

    var body: some View {
        VStack(spacing: 12) {
            // Tool selection
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AnnotationTool.allCases) { tool in
                        Button {
                            selectedTool = tool
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: tool.systemImage)
                                    .font(.system(size: 18))
                                Text(tool.localizedName(language: seggwat.options.language))
                                    .font(.caption2)
                            }
                            .frame(minWidth: 52, minHeight: 48)
                            .foregroundColor(selectedTool == tool ? .white : .primary)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedTool == tool ? seggwat.options.buttonColor : Color(.systemGray5))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }

            // Color selection
            HStack(spacing: 12) {
                ForEach(AnnotationColor.allCases) { preset in
                    Button {
                        selectedColor = preset
                    } label: {
                        Circle()
                            .fill(preset.color)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: selectedColor == preset ? 2 : 0)
                                    .padding(-2)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Stroke width
                Picker("", selection: $strokeWidth) {
                    Text(seggwat.localizedString("screenshot_stroke_thin")).tag(CGFloat(2))
                    Text(seggwat.localizedString("screenshot_stroke_medium")).tag(CGFloat(4))
                    Text(seggwat.localizedString("screenshot_stroke_thick")).tag(CGFloat(8))
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}
