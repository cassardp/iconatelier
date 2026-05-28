import SwiftUI
import UIKit

/// Sheet to share an icon to the web gallery (or update / remove an existing publication).
struct PublishSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProjectStore.self) private var store

    @Bindable var project: IconProject

    @State private var state: PublishState = .idle
    @State private var tagsText = ""
    @State private var hasDeleteToken = false

    enum PublishState: Equatable {
        case idle, working, done, failed(String)
    }

    var body: some View {
        NavigationStack {
            Form {
                previewSection
                infoSection
                actionSection
                if case .failed(let message) = state {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Share to Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                tagsText = project.tags.joined(separator: ", ")
                hasDeleteToken = await CommunityCredentialStore.shared.token(for: project.uuid) != nil
            }
        }
    }

    // MARK: - Sections

    private var previewSection: some View {
        Section {
            HStack {
                Spacer()
                iconThumbnail
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(Color.clear)
    }

    private var infoSection: some View {
        Section("Details") {
            TextField("Title", text: $project.title)
            TextField("Author", text: authorBinding)
                .textInputAutocapitalization(.words)
            TextField("App Store URL", text: appStoreURLBinding)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Tags (comma separated)", text: $tagsText)
                .textInputAutocapitalization(.never)
        }
    }

    @ViewBuilder
    private var actionSection: some View {
        Section {
            if project.isPublic {
                LabeledContent("Status") {
                    Label("Published", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .labelStyle(.titleAndIcon)
                }
                Button {
                    Task { await publish() }
                } label: {
                    rowLabel("Update publication", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(!hasDeleteToken)
                Button(role: .destructive) {
                    Task { await remove() }
                } label: {
                    rowLabel("Remove from gallery", systemImage: "trash")
                }
                .disabled(!hasDeleteToken)
                if !hasDeleteToken {
                    Text("This icon was published from another device or by someone else, so it can't be updated or removed here. Duplicate it to publish your own version.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    Task { await publish() }
                } label: {
                    rowLabel("Publish to gallery", systemImage: "square.and.arrow.up")
                }
            }
        } footer: {
            if case .done = state {
                Text("Done. Your icon is live in the gallery.")
                    .foregroundStyle(.green)
            }
        }
        .disabled(state == .working)
        .overlay(alignment: .trailing) {
            if state == .working {
                ProgressView().padding(.trailing)
            }
        }
    }

    @ViewBuilder
    private var iconThumbnail: some View {
        let side: CGFloat = 120
        let shape = RoundedRectangle(cornerRadius: side * 0.2237, style: .continuous)
        Group {
            if let data = project.thumbnailPNG, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(uiColor: .secondarySystemBackground)
            }
        }
        .frame(width: side, height: side)
        .clipShape(shape)
        .overlay(shape.stroke(Color.primary.opacity(0.06), lineWidth: 1))
    }

    private func rowLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .labelStyle(.titleAndIcon)
    }

    // MARK: - Bindings to optional fields

    private var authorBinding: Binding<String> {
        Binding(
            get: { project.authorName ?? "" },
            set: { project.authorName = $0.isEmpty ? nil : $0 }
        )
    }

    private var appStoreURLBinding: Binding<String> {
        Binding(
            get: { project.appStoreURL?.absoluteString ?? "" },
            set: { project.appStoreURL = URL(string: $0.trimmingCharacters(in: .whitespaces)) }
        )
    }

    // MARK: - Actions

    private func applyEdits() {
        project.tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        project.updatedAt = .now
    }

    private func publish() async {
        applyEdits()
        store.save(project)
        state = .working
        do {
            let response = try await CommunityService().publish(project)
            if let token = response.deleteToken {
                await CommunityCredentialStore.shared.save(token, for: project.uuid)
                hasDeleteToken = true
            }
            project.isPublic = true
            project.publishedID = response.icon.id
            project.publishedAt = .now
            store.save(project)
            state = .done
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func remove() async {
        guard let id = project.publishedID,
              let token = await CommunityCredentialStore.shared.token(for: project.uuid) else {
            state = .failed("Missing delete key for this icon on this device.")
            return
        }
        state = .working
        do {
            try await CommunityService().delete(id: id, token: token)
            await CommunityCredentialStore.shared.delete(for: project.uuid)
            project.isPublic = false
            project.publishedID = nil
            project.publishedAt = nil
            store.save(project)
            hasDeleteToken = false
            state = .idle
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
