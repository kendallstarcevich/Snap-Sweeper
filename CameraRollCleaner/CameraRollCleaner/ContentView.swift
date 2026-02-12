import SwiftUI

// --- PAGE 1: The Home Dashboard ---
struct ContentView: View {
    var body: some View {
        NavigationStack { // 1. This is the "Engine" of navigation
            VStack(spacing: 30) {
                Text("Photo Cleaner AI")
                    .font(.largeTitle)
                    .bold()
                
                Image(systemName: "photo.stack")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundStyle(.blue)
                
                // 2. This is like an <a href="..."> tag
                NavigationLink(destination: ResultsView()) {
                    Text("View Redundant Photos")
                        .fontWeight(.semibold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .navigationTitle("Home") // Adds a title at the top
        }
    }
}

// --- PAGE 2: The Results Page ---
struct ResultsView: View {
    var body: some View {
        VStack {
            Text("We found 20 duplicates!")
                .font(.title2)
            
            List {
                Text("Tree_Photo_1.jpg")
                Text("Tree_Photo_2.jpg")
                Text("Tree_Photo_3.jpg")
            }
        }
        .navigationTitle("Scanning Results") // 3. Back button appears automatically
    }
}

#Preview {
    ContentView()
}
