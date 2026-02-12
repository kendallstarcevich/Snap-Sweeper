import SwiftUI

struct ContentView: View {
    // We create the manager here once
    @StateObject var photoManager = PhotoManager()

    var body: some View {
        NavigationStack {
            VStack(spacing: 25) {
                Text("AI Photo Cleaner")
                    .font(.largeTitle).bold()
                
                // Dashboard stats
                HStack(spacing: 40) {
                    StatView(label: "Total", value: photoManager.photoCount)
                    StatView(label: "Screenshots", value: photoManager.screenshotCount, color: .red)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(15)

                if !photoManager.isAuthorized {
                    Button("Grant Library Access") {
                        photoManager.requestAccessAndFetch()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    // Navigate to the results page
                    NavigationLink(destination: ResultsView(count: photoManager.screenshotCount)) {
                        Text("Review Screenshots")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            }
            .padding()
            .navigationTitle("Dashboard")
            .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(action: {
                                    photoManager.requestAccessAndFetch()
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                }
                            }
                        }
        }
    }
}

// A small helper view to keep code clean (like a component in React)
struct StatView: View {
    var label: String
    var value: Int
    var color: Color = .primary
    
    var body: some View {
        VStack {
            Text("\(value)")
                .font(.title).bold()
                .foregroundColor(color)
            Text(label)
                .font(.caption)
        }
    }
}

// Update the ResultsView to accept data
struct ResultsView: View {
    let count: Int
    
    var body: some View {
        VStack {
            Text("Found \(count) Screenshots")
                .font(.headline)
            List(0..<count, id: \.self) { _ in
                Text("Screenshot Preview Placeholder")
                
            }
        }
        .navigationTitle("Clean Up")
    }
}

#Preview {
    ContentView()
}
