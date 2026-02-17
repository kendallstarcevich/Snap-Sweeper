import SwiftUI
import Photos // Essential for PHAsset

struct ContentView: View {
    @StateObject var photoManager = PhotoManager()

    var body: some View {
        NavigationStack {
            VStack(spacing: 25) {
                Text("AI Photo Cleaner")
                    .font(.largeTitle).bold()
                
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
                    NavigationLink(destination: ResultsView(assets: photoManager.screenshotAssets)) {
                        Text("Review \(photoManager.screenshotCount) Screenshots")
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

struct ResultsView: View {
    let assets: [PHAsset]
    
    let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(assets, id: \.localIdentifier) { asset in
                    PhotoThumbnail(asset: asset)
                        .frame(height: 120)
                        .clipped()
                }
            }
        }
        .navigationTitle("Screenshots")
    }
}

struct PhotoThumbnail: View {
    let asset: PHAsset
    @State private var image: UIImage? = nil

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.gray.opacity(0.2)
            }
        }
        .onAppear {
            loadImage()
        }
    }

    func loadImage() {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        
        manager.requestImage(for: asset,
                             targetSize: CGSize(width: 200, height: 200),
                             contentMode: .aspectFill,
                             options: options) { result, _ in
            self.image = result
        }
    }
}

#Preview {
    ContentView()
}
