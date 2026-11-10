import SwiftUI

struct InitialView: View {
    var body: some View {
        HStack(spacing: 80) {
            LeftPanel()
            RightPanel()
        }
        .padding()
    }
}

#Preview {
    InitialView()
        .frame(width: 600, height: 400)
}
