import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 72))
                .foregroundColor(.blue)
            
            Text("Code iOS")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.primary)
            
            Text("iPhone 原生开发工作站")
                .font(.system(size: 18))
                .foregroundColor(.secondary)
            
            Divider()
                .margin(.vertical)
            
            Text("🚀 云端构建中...")
                .font(.system(size: 16))
                .foregroundColor(.accentColor)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            
            Spacer()
        }
        .padding()
        .onAppear {
            print("Code iOS app started!")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
