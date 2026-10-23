import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "terminal")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            
            Text("Code iOS")
                .font(.title)
                .fontWeight(.bold)
            
            Text("iPhone 原生开发工作站")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
                .margin(.vertical)
            
            Text("项目正在初始化...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
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
