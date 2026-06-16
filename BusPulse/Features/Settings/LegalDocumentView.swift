import SwiftUI

/// Renders a plain-text legal document with selectable text.
struct LegalDocumentView: View {
    let title: String
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .font(.callout)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(BPSpacing.screenMargin)
        }
        .background(BPColor.backgroundPrimary)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
