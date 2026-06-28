import SwiftUI
import PhotosUI
import AppFactoryKit

// AI Avatar / Profile Pics — pick a selfie, get a stylized avatar. Stylization
// runs on-device (segmentation + Core Image); Pro unlocks all styles and saving.
// RemoteAvatarService is the seam for full generative avatars.
struct ContentView: View {
    @EnvironmentObject private var factory: AppFactory
    private let service: AvatarGenerating = OnDeviceAvatarService()

    @State private var pickerItem: PhotosPickerItem?
    @State private var inputImage: UIImage?
    @State private var outputImage: UIImage?
    @State private var style: AvatarStyle = .all[0]
    @State private var isProcessing = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    preview
                    styleRow
                    actions
                    if let errorText { Text(errorText).font(.footnote).foregroundStyle(.red) }
                }
                .padding(20)
            }
            .navigationTitle("AI Avatar")
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await load(item) }
        }
    }

    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18).fill(.quaternary)
            if let shown = outputImage ?? inputImage {
                Image(uiImage: shown).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 18))
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.badge.plus").font(.system(size: 54)).foregroundStyle(.purple)
                    Text("Pick a selfie").foregroundStyle(.secondary)
                }
            }
            if isProcessing { ProgressView().controlSize(.large) }
        }
        .frame(height: 340)
    }

    private var styleRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(AvatarStyle.all) { s in
                    Button { select(s) } label: {
                        VStack(spacing: 6) {
                            LinearGradient(colors: [Color(s.top), Color(s.bottom)], startPoint: .top, endPoint: .bottom)
                                .frame(width: 56, height: 56).clipShape(Circle())
                                .overlay(Circle().strokeBorder(.white, lineWidth: style == s ? 3 : 0))
                                .overlay(alignment: .topTrailing) {
                                    if s.isPremium && !factory.subscriptions.isSubscribed {
                                        Image(systemName: "lock.fill").font(.system(size: 11)).padding(4)
                                            .background(.ultraThinMaterial, in: Circle())
                                    }
                                }
                            Text(s.name).font(.caption2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label(inputImage == nil ? "Choose Selfie" : "Choose Another", systemImage: "photo")
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.bordered)

            if outputImage != nil {
                Button { factory.requirePremium(feature: "save_avatar") { save() } } label: {
                    Label("Save to Photos", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func select(_ s: AvatarStyle) {
        if s.isPremium && !factory.subscriptions.isSubscribed {
            factory.presentPaywall(placement: "style_\(s.id)"); return
        }
        style = s
        if inputImage != nil { Task { await generate() } }
    }

    private func load(_ item: PhotosPickerItem) async {
        errorText = nil
        if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
            inputImage = img; outputImage = nil
            await generate()
        } else { errorText = "Couldn't load that photo." }
    }

    private func generate() async {
        guard let inputImage else { return }
        isProcessing = true; errorText = nil
        defer { isProcessing = false }
        do { outputImage = try await service.generate(from: inputImage, style: style) }
        catch { errorText = "Couldn't stylize that photo." }
    }

    private func save() {
        guard let outputImage else { return }
        UIImageWriteToSavedPhotosAlbum(outputImage, nil, nil, nil)
    }
}
