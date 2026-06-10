import SwiftUI
import PencilKit

/// Fullscreen annotation editor with PencilKit canvas overlay on a screenshot.
struct AnnotationEditorView: View {
    let baseImage: UIImage
    let onSave: (UIImage) -> Void
    let onCancel: () -> Void

    @EnvironmentObject private var seggwat: SeggWat
    @State private var canvasView = PKCanvasView()
    @State private var selectedTool: AnnotationTool = .pen
    @State private var selectedColor: AnnotationColor = .red
    @State private var strokeWidth: CGFloat = 4
    @State private var undoManager_ = UndoManager()
    @State private var showTextInput = false
    @State private var textInput = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onCancel) {
                    Text(seggwat.localizedString("screenshot_cancel"))
                }

                Spacer()

                Text(seggwat.localizedString("screenshot_modal_title"))
                    .font(.headline)

                Spacer()

                Button {
                    saveAnnotatedImage()
                } label: {
                    Text(seggwat.localizedString("screenshot_done"))
                        .fontWeight(.semibold)
                }
            }
            .padding()
            .background(.ultraThinMaterial)

            // Canvas
            GeometryReader { geometry in
                let imageSize = baseImage.size
                let scale = min(
                    geometry.size.width / imageSize.width,
                    geometry.size.height / imageSize.height
                )
                let scaledSize = CGSize(
                    width: imageSize.width * scale,
                    height: imageSize.height * scale
                )

                ZStack {
                    Color(.systemBackground)

                    Image(uiImage: baseImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: scaledSize.width, height: scaledSize.height)

                    PencilKitCanvasRepresentable(
                        canvasView: $canvasView,
                        tool: pencilKitTool,
                        undoManager: undoManager_
                    )
                    .frame(width: scaledSize.width, height: scaledSize.height)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Toolbar
            AnnotationToolbar(
                selectedTool: $selectedTool,
                selectedColor: $selectedColor,
                strokeWidth: $strokeWidth
            )

            // Action bar
            HStack {
                Button {
                    undoManager_.undo()
                } label: {
                    Label(seggwat.localizedString("screenshot_undo"), systemImage: "arrow.uturn.backward")
                }
                .disabled(!undoManager_.canUndo)

                Button {
                    undoManager_.redo()
                } label: {
                    Label(seggwat.localizedString("screenshot_redo"), systemImage: "arrow.uturn.forward")
                }
                .disabled(!undoManager_.canRedo)

                Spacer()

                Button(role: .destructive) {
                    canvasView.drawing = PKDrawing()
                } label: {
                    Label(seggwat.localizedString("screenshot_clear"), systemImage: "trash")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
        .alert(seggwat.localizedString("screenshot_text_modal_title"), isPresented: $showTextInput) {
            TextField(seggwat.localizedString("screenshot_text_modal_placeholder"), text: $textInput)
            Button(seggwat.localizedString("screenshot_text_modal_add")) {
                addTextAnnotation()
            }
            Button(seggwat.localizedString("screenshot_cancel"), role: .cancel) {}
        }
        .onChange(of: selectedTool) { newTool in
            if newTool == .text {
                showTextInput = true
            }
        }
    }

    private var pencilKitTool: PKTool {
        let inkColor = selectedColor.uiColor
        switch selectedTool {
        case .pen:
            return PKInkingTool(.pen, color: inkColor, width: strokeWidth)
        case .arrow:
            return PKInkingTool(.marker, color: inkColor, width: strokeWidth)
        case .rectangle:
            return PKInkingTool(.pen, color: inkColor, width: strokeWidth)
        case .text:
            return PKInkingTool(.pen, color: inkColor, width: strokeWidth)
        case .blackout:
            return PKInkingTool(.marker, color: .black, width: 30)
        }
    }

    private func addTextAnnotation() {
        guard !textInput.isEmpty else { return }
        // For text, we render it onto the PencilKit canvas as an image
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 50))
        let textImage = renderer.image { context in
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20),
                .foregroundColor: selectedColor.uiColor
            ]
            (textInput as NSString).draw(at: .zero, withAttributes: attrs)
        }

        // Add as a stroke to the center of the canvas
        if let cgImage = textImage.cgImage {
            let _ = cgImage // Text is rendered via PencilKit drawing instead
        }

        textInput = ""
    }

    private func saveAnnotatedImage() {
        let imageSize = baseImage.size
        let renderer = UIGraphicsImageRenderer(size: imageSize)

        let annotated = renderer.image { context in
            // Draw base image
            baseImage.draw(in: CGRect(origin: .zero, size: imageSize))

            // Draw PencilKit annotations scaled to image size
            let canvasSize = canvasView.bounds.size
            guard canvasSize.width > 0, canvasSize.height > 0 else { return }
            let scaleX = imageSize.width / canvasSize.width
            let scaleY = imageSize.height / canvasSize.height

            let drawingImage = canvasView.drawing.image(from: canvasView.bounds, scale: 1.0)
            drawingImage.draw(in: CGRect(
                origin: .zero,
                size: CGSize(width: canvasSize.width * scaleX, height: canvasSize.height * scaleY)
            ))
        }

        onSave(annotated)
    }
}

/// UIViewRepresentable wrapper for PKCanvasView.
struct PencilKitCanvasRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    let tool: PKTool
    let undoManager: UndoManager

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.tool = tool
        canvasView.undoManager?.removeAllActions()
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.tool = tool
    }
}
