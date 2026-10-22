import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LibraryStore.self) private var library
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("metadataProvider") private var metadataProvider = MetadataProvider.tmdb.rawValue
    @AppStorage(AppConfiguration.proxyBaseURLKey) private var tmdbAPIBaseURL = ""
    @State private var exportDocument: LibraryBackupDocument?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var showClearConfirmation = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var isProbing = false
    @State private var probeMessage: String?
    @State private var probeSucceeded = false

    private var provider: MetadataProvider {
        MetadataProvider(rawValue: metadataProvider) ?? .tmdb
    }

    private var usesBangumi: Binding<Bool> {
        Binding(
            get: { provider == .bangumi },
            set: { isOn in
                metadataProvider = isOn
                    ? MetadataProvider.bangumi.rawValue
                    : MetadataProvider.tmdb.rawValue
                probeMessage = nil
            }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                displaySection
                providerSection
                dataSection
                aboutSection
                developerSection
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("好", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .fileExporter(
                isPresented: $isExporting,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "AnimeMemo-Backup"
            ) { result in
                switch result {
                case .success:
                    presentAlert("导出成功", "备份文件已保存。")
                case .failure(let error):
                    presentAlert("导出失败", error.localizedDescription)
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.json]
            ) { result in
                switch result {
                case .success(let url):
                    importBackup(from: url)
                case .failure(let error):
                    presentAlert("导入失败", error.localizedDescription)
                }
            }
            .confirmationDialog("确定清空全部数据？", isPresented: $showClearConfirmation, titleVisibility: .visible) {
                Button("清空", role: .destructive) {
                    library.clear()
                    presentAlert("已清空", "本地片库已清空。")
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("这个操作不可撤销。建议先导出备份。")
            }
        }
    }

    private var displaySection: some View {
        Section("显示") {
            Picker("外观", selection: $appearance) {
                Text("跟随系统").tag("system")
                Text("浅色").tag("light")
                Text("深色").tag("dark")
            }
            .pickerStyle(.segmented)
        }
    }

    private var providerSection: some View {
        Section("数据源") {
            Toggle("使用 Bangumi 数据源", isOn: usesBangumi)

            Text(providerDetail)
                .font(.caption)
                .foregroundStyle(.secondary)

            if provider == .tmdb {
                proxySettings
            }

            probeButton

            if let probeMessage {
                Text(probeMessage)
                    .font(.caption)
                    .foregroundStyle(probeSucceeded ? Color.secondary : Color.red)
            }
        }
    }

    private var providerDetail: String {
        if provider == .bangumi {
            return "当前使用 Bangumi：中文条目更贴近国内，可直连，但没有 TMDB 式的自动分季聚合。"
        }
        return "当前使用 TMDB：海报和分季更完整，中国大陆通常需要反向代理。"
    }

    @ViewBuilder
    private var proxySettings: some View {
        TextField("TMDB 反向代理地址（可选）", text: $tmdbAPIBaseURL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.URL)

        Text("留空使用官方 API。中国真机建议填自己的代理地址，例如 https://你的域名/3 。")
            .font(.caption2)
            .foregroundStyle(.tertiary)

        if !tmdbAPIBaseURL.isEmpty {
            Button("恢复官方 API") {
                tmdbAPIBaseURL = ""
                probeMessage = nil
            }
            .font(.caption.weight(.semibold))
        }
    }

    private var probeButton: some View {
        Button {
            Task { await probeProvider() }
        } label: {
            HStack {
                Label("测试当前数据源", systemImage: "antenna.radiowaves.left.and.right")
                Spacer(minLength: 8)
                if isProbing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .disabled(isProbing)
    }

    private var dataSection: some View {
        Section("数据") {
            Button {
                exportBackup()
            } label: {
                Label("导出备份", systemImage: "square.and.arrow.up")
            }

            Button {
                isImporting = true
            } label: {
                Label("导入备份", systemImage: "square.and.arrow.down")
            }

            Button(role: .destructive) {
                showClearConfirmation = true
            } label: {
                Label("清空全部数据", systemImage: "trash")
            }
        }
    }

    private var aboutSection: some View {
        Section("关于") {
            LabeledContent("版本", value: "0.1.0")

            if provider == .tmdb {
                Link(destination: URL(string: "https://www.themoviedb.org")!) {
                    Label("数据来源：TMDB", systemImage: "film.stack")
                }

                Text("This product uses the TMDB API but is not endorsed or certified by TMDB.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Link(destination: URL(string: "https://bgm.tv")!) {
                    Label("数据来源：Bangumi 番组计划", systemImage: "sparkles")
                }

                Text("数据来自 Bangumi 番组计划。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var developerSection: some View {
        #if DEBUG
        Section("开发者") {
            LabeledContent("TMDB", value: AppConfiguration.isTMDBConfigured ? "已配置" : "未配置")
            LabeledContent("代理", value: AppConfiguration.tmdbAPIBaseURLIsDefault ? "官方 API" : AppConfiguration.tmdbAPIBaseURL.absoluteString)
            LabeledContent("Bangumi", value: "免 token")

            NavigationLink("Glass Lab") {
                GlassLabView()
            }
        }
        #endif
    }

    private func probeProvider() async {
        isProbing = true
        probeMessage = nil

        let target = provider
        do {
            let result = try await ProviderProbe.run(target)
            probeMessage = "\(result.summary)\n示例：\(result.sampleTitle)"
            probeSucceeded = true
        } catch {
            probeMessage = error.localizedDescription
            probeSucceeded = false
        }

        isProbing = false
    }

    private func importBackup(from url: URL) {
        do {
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let data = try Data(contentsOf: url)
            try library.importData(data)
            presentAlert("导入成功", "已导入 \(library.entries.count) 部作品。")
        } catch {
            presentAlert("导入失败", error.localizedDescription)
        }
    }

    private func exportBackup() {
        do {
            let data = try library.exportData()
            exportDocument = LibraryBackupDocument(data: data)
            isExporting = true
        } catch {
            presentAlert("导出失败", error.localizedDescription)
        }
    }

    private func presentAlert(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}
