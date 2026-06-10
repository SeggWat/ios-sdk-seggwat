import SwiftUI

/// Fullscreen annotation editor: draw pen strokes, arrows, rectangles, text and
/// blackout boxes on top of a captured screenshot, then flatten to a new image.
struct AnnotationEditorView: View {
    let baseImage: UIImage
    let onSave: (UIImage) -> Void
    let onCancel: () -> Void

    @EnvironmentObject private var seggwat: SeggWat

    @State private var selectedTool: AnnotationTool = .pen
    @State private var selectedColor: AnnotationColor = .red
    @State private var strokeWidth: CGFloat = 4

    @State private var annotations: [Annotation] = []
    @State private var redoStack: [Annotation] = []
    @State private var current: Annotation?

    @State private var canvasSize: CGSize = .zero

    @State private var showTextInput = false
    @State private var textInput = ""
    @State private var pendingTextLocation: CGPoint = .zero

    private let strokeOptions: [CGFloat] = [2, 5, 9]

    var body: some View {
        VStack(spacing: 0) {
            header
            canvas
            Divider()
            AnnotationToolbar(
                selectedTool: $selectedTool,
                selectedColor: $selectedColor,
                strokeWidth: $strokeWidth
            )
            actionBar
        }
        .background(Color(.systemBackground))
        .alert(seggwat.localizedString("screenshot_text_modal_title"), isPresented: $showTextInput) {
            TextField(seggwat.localizedString("screenshot_text_modal_placeholder"), text: $textInput)
            Button(seggwat.localizedString("screenshot_text_modal_add")) { addTextAnnotation() }
            Button(seggwat.localizedString("screenshot_cancel"), role: .cancel) { textInput = "" }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(seggwat.localizedString("screenshot_cancel"), action: onCancel)

            Spacer()

            Text(seggwat.localizedString("screenshot_modal_title"))
                .font(.headline)

            Spacer()

            Button(action: save) {
                Text(seggwat.localizedString("screenshot_done"))
                    .fontWeight(.semibold)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(seggwat.options.buttonColor, in: Capsule())
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    // MARK: - Canvas

    private var canvas: some View {
        GeometryReader { geo in
            let size = fittedSize(for: baseImage.size, in: geo.size)
            ZStack {
                Color(.systemGroupedBackground)

                ZStack {
                    Image(uiImage: baseImage)
                        .resizable()
                        .frame(width: size.width, height: size.height)

                    AnnotationCanvas(annotations: annotations, current: current)
                        .frame(width: size.width, height: size.height)
                        .contentShape(Rectangle())
                        .gesture(drawGesture)
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { canvasSize = size }
            .onChange(of: geo.size) { _ in canvasSize = size }
        }
    }

    private var drawGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard selectedTool != .text else { return }
                if current == nil {
                    var ann = Annotation(tool: selectedTool, color: selectedColor, lineWidth: strokeWidth)
                    ann.start = value.startLocation
                    ann.points = [value.startLocation]
                    current = ann
                }
                current?.end = value.location
                if selectedTool == .pen {
                    current?.points.append(value.location)
                }
            }
            .onEnded { value in
                if selectedTool == .text {
                    pendingTextLocation = value.location
                    showTextInput = true
                    return
                }
                if let ann = current, isMeaningful(ann) {
                    commit(ann)
                }
                current = nil
            }
    }

    // MARK: - Action bar (stroke width + undo/redo/clear)

    private var actionBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 10) {
                ForEach(strokeOptions, id: \.self) { width in
                    Button {
                        strokeWidth = width
                    } label: {
                        Circle()
                            .fill(strokeWidth == width ? Color.primary : Color(.systemGray3))
                            .frame(width: width + 6, height: width + 6)
                            .frame(width: 34, height: 34)
                            .background(
                                Circle().fill(strokeWidth == width ? Color(.systemGray5) : .clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(strokeLabel(for: width))
                }
            }

            Spacer()

            Button(action: undo) {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(annotations.isEmpty)
            .accessibilityLabel(seggwat.localizedString("screenshot_undo"))

            Button(action: redo) {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(redoStack.isEmpty)
            .accessibilityLabel(seggwat.localizedString("screenshot_redo"))

            Button(role: .destructive, action: clear) {
                Label(seggwat.localizedString("screenshot_clear"), systemImage: "trash")
                    .labelStyle(.titleAndIcon)
            }
            .disabled(annotations.isEmpty && current == nil)
        }
        .font(.body)
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private func strokeLabel(for width: CGFloat) -> String {
        switch width {
        case strokeOptions.first: return seggwat.localizedString("screenshot_stroke_thin")
        case strokeOptions.last: return seggwat.localizedString("screenshot_stroke_thick")
        default: return seggwat.localizedString("screenshot_stroke_medium")
        }
    }

    // MARK: - Mutations

    private func commit(_ ann: Annotation) {
        annotations.append(ann)
        redoStack.removeAll()
    }

    private func undo() {
        guard let last = annotations.popLast() else { return }
        redoStack.append(last)
    }

    private func redo() {
        guard let last = redoStack.popLast() else { return }
        annotations.append(last)
    }

    private func clear() {
        annotations.removeAll()
        redoStack.removeAll()
        current = nil
    }

    private func addTextAnnotation() {
        let trimmed = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        textInput = ""
        guard !trimmed.isEmpty else { return }
        var ann = Annotation(tool: .text, color: selectedColor, lineWidth: strokeWidth)
        ann.text = trimmed
        ann.start = pendingTextLocation
        commit(ann)
    }

    /// Reject accidental zero-size shapes; allow any pen stroke.
    private func isMeaningful(_ ann: Annotation) -> Bool {
        switch ann.tool {
        case .pen:
            return ann.points.count > 1
        case .arrow, .rectangle, .blackout:
            return hypot(ann.end.x - ann.start.x, ann.end.y - ann.start.y) > 6
        case .text:
            return false
        }
    }

    // MARK: - Flatten to image

    @MainActor private func save() {
        guard canvasSize.width > 0, canvasSize.height > 0 else {
            onSave(baseImage)
            return
        }

        let content = ZStack {
            Image(uiImage: baseImage)
                .resizable()
                .frame(width: canvasSize.width, height: canvasSize.height)
            AnnotationCanvas(annotations: annotations, current: nil)
                .frame(width: canvasSize.width, height: canvasSize.height)
        }
        .frame(width: canvasSize.width, height: canvasSize.height)

        let renderer = ImageRenderer(content: content)
        // Render at the screenshot's native pixel resolution.
        renderer.scale = baseImage.scale * baseImage.size.width / canvasSize.width

        onSave(renderer.uiImage ?? baseImage)
    }

    private func fittedSize(for imageSize: CGSize, in bounds: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }
}

/// Renders committed annotations plus the in-progress one onto a SwiftUI canvas.
struct AnnotationCanvas: View {
    let annotations: [Annotation]
    let current: Annotation?

    var body: some View {
        Canvas { context, _ in
            for ann in annotations {
                draw(ann, in: &context)
            }
            if let current {
                draw(current, in: &context)
            }
        }
    }

    private func draw(_ ann: Annotation, in context: inout GraphicsContext) {
        let color = ann.color.color
        let style = StrokeStyle(lineWidth: ann.lineWidth, lineCap: .round, lineJoin: .round)

        switch ann.tool {
        case .pen:
            guard ann.points.count > 1 else { return }
            var path = Path()
            path.addLines(ann.points)
            context.stroke(path, with: .color(color), style: style)

        case .arrow:
            context.stroke(arrowPath(from: ann.start, to: ann.end, lineWidth: ann.lineWidth),
                           with: .color(color), style: style)

        case .rectangle:
            let path = Path(roundedRect: rect(ann.start, ann.end), cornerRadius: 4)
            context.stroke(path, with: .color(color), style: style)

        case .blackout:
            context.fill(Path(rect(ann.start, ann.end)), with: .color(.black))

        case .text:
            guard !ann.text.isEmpty else { return }
            let resolved = context.resolve(
                Text(ann.text)
                    .font(.system(size: textSize(for: ann.lineWidth), weight: .semibold))
                    .foregroundColor(color)
            )
            context.draw(resolved, at: ann.start, anchor: .topLeading)
        }
    }

    private func arrowPath(from start: CGPoint, to end: CGPoint, lineWidth: CGFloat) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)

        let angle = atan2(end.y - start.y, end.x - start.x)
        let headLength = max(14, lineWidth * 3.5)
        let headAngle = CGFloat.pi / 6
        path.move(to: end)
        path.addLine(to: CGPoint(
            x: end.x - headLength * cos(angle - headAngle),
            y: end.y - headLength * sin(angle - headAngle)
        ))
        path.move(to: end)
        path.addLine(to: CGPoint(
            x: end.x - headLength * cos(angle + headAngle),
            y: end.y - headLength * sin(angle + headAngle)
        ))
        return path
    }

    private func rect(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
               width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    private func textSize(for lineWidth: CGFloat) -> CGFloat {
        12 + lineWidth * 2.5
    }
}
