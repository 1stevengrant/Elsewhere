import SwiftUI

struct RightPanel: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Welcome to Elsewhere")
                .font(.headline)
            Text("Keep your favourite timezones close at hand.")
                .font(.callout)
            PrimaryButton(title: "Get started", action: {
                UserDefaults.standard.set(true, forKey: "hasCompletedInitialSetup")
                appState.presentMenu()
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
