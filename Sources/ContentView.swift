import SwiftUI

struct ContentView: View {
    @State private var logText = ""
    @State private var isConnecting = false
    @State private var buildStatus = "Ready"

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Code iOS")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Text("v1.0.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            Divider()

            // Status Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                    Text("GitHub Actions 已连接")
                        .font(.headline)
                }

                Text("Build Status: \(buildStatus)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    Text("Runner:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("macos-14")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                HStack {
                    Text("Repository:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("yoyo520956/code-ios")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Log Output
            VStack(alignment: .leading) {
                Text("Build Log")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                ScrollView {
                    Text(logText.isEmpty ? "Waiting for build output..." : logText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .padding(.horizontal)

            Spacer()

            // Action Button
            Button(action: triggerBuild) {
                HStack {
                    Image(systemName: "hammer.fill")
                    Text("Trigger Build")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding()
            .disabled(isConnecting)
        }
        .onAppear {
            logText = "Initialized. Ready to build.\n"
        }
    }

    private func triggerBuild() {
        isConnecting = true
        buildStatus = "Building..."
        logText += "Triggering GitHub Actions workflow...\n"

        // Simulate build process
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            buildStatus = "Success"
            logText += "Workflow completed successfully.\n"
            isConnecting = false
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}