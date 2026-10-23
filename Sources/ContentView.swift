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
            
            Spacer()
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
