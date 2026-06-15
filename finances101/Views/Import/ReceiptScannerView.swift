import SwiftUI
import Vision
import VisionKit

struct ReceiptScannerView: View {
    var onResult: (Decimal, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showScanner = false
    @State private var scannedAmount: Decimal?
    @State private var scannedTitle: String = ""
    @State private var rawText: String = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if isProcessing {
                    ProgressView("Scanning receipt...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let amount = scannedAmount {
                    resultView(amount: amount)
                } else {
                    promptView
                }
            }
            .padding()
            .navigationTitle("Scan Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showScanner) {
                if VNDocumentCameraViewController.isSupported {
                    DocumentScannerRepresentable { images in
                        isProcessing = true
                        processImages(images)
                    }
                } else {
                    Text("Document scanning not supported on this device.")
                        .padding()
                }
            }
        }
    }

    private var promptView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 72))
                .foregroundStyle(AppColors.primaryDeep.opacity(0.3))

            VStack(spacing: 8) {
                Text("Scan a Receipt")
                    .font(.title2.weight(.bold))
                Text("Camera will capture the receipt and extract the total amount automatically.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(AppColors.expense)
            }

            Button {
                showScanner = true
            } label: {
                Label("Open Camera", systemImage: "camera.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.primaryDeep)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func resultView(amount: Decimal) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppColors.income)

            Text("Receipt Scanned")
                .font(.title2.weight(.bold))

            VStack(spacing: 16) {
                HStack {
                    Text("Amount")
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    Text("$\(amount.formatted(.number.precision(.fractionLength(2))))")
                        .font(.headline)
                }
                if !scannedTitle.isEmpty {
                    HStack {
                        Text("Merchant")
                            .foregroundStyle(AppColors.textSecondary)
                        Spacer()
                        Text(scannedTitle)
                            .font(.headline)
                    }
                }
            }
            .padding()
            .appCard()

            VStack(spacing: 12) {
                Button {
                    onResult(amount, scannedTitle)
                    dismiss()
                } label: {
                    Text("Use This Amount")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.primaryDeep)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    scannedAmount = nil
                    scannedTitle = ""
                    rawText = ""
                } label: {
                    Text("Scan Again")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }

    private func processImages(_ images: [UIImage]) {
        DispatchQueue.global(qos: .userInitiated).async {
            var allText = ""
            let group = DispatchGroup()

            for image in images.prefix(3) {
                group.enter()
                guard let cgImage = image.cgImage else { group.leave(); continue }
                let request = VNRecognizeTextRequest { req, _ in
                    let observations = req.results as? [VNRecognizedTextObservation] ?? []
                    let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                    allText += text + "\n"
                    group.leave()
                }
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            }

            group.notify(queue: .main) {
                rawText = allText
                let (amount, title) = extractReceiptData(from: allText)
                isProcessing = false
                if let amount {
                    scannedAmount = amount
                    scannedTitle = title
                } else {
                    errorMessage = "Could not find a total amount. Try scanning again."
                }
            }
        }
    }

    private func extractReceiptData(from text: String) -> (Decimal?, String) {
        let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }

        // Find the total amount — look for lines with "total", "amount due", "balance due"
        let totalKeywords = ["total due", "amount due", "balance due", "total:", "grand total", "total"]
        var amount: Decimal?

        for keyword in totalKeywords {
            for line in lines where line.lowercased().contains(keyword) {
                if let found = extractAmount(from: line) {
                    amount = found
                    break
                }
            }
            if amount != nil { break }
        }

        // If still no total, pick the largest dollar amount on the receipt
        if amount == nil {
            let amounts = lines.compactMap { extractAmount(from: $0) }
            amount = amounts.max()
        }

        // Title: first non-empty line, or line before total
        let title = lines.first(where: { !$0.isEmpty && !$0.hasPrefix("$") }) ?? ""

        return (amount, title)
    }

    private func extractAmount(from line: String) -> Decimal? {
        // Match patterns like $12.34 or 12.34 or 12,34
        let pattern = #"[\$]?\s?(\d{1,6}[.,]\d{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line) else { return nil }
        let numStr = String(line[range]).replacingOccurrences(of: ",", with: ".")
        return Decimal(userInput: numStr)
    }
}

// MARK: - VisionKit wrapper

struct DocumentScannerRepresentable: UIViewControllerRepresentable {
    var onScan: ([UIImage]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: ([UIImage]) -> Void
        init(onScan: @escaping ([UIImage]) -> Void) { self.onScan = onScan }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for i in 0..<scan.pageCount { images.append(scan.imageOfPage(at: i)) }
            controller.dismiss(animated: true) { self.onScan(images) }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true)
        }
    }
}
