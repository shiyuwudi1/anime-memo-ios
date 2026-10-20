import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LibraryStore.self) private var library
    @AppStorage("appearance") private var appearance = "system"
    @State private var exportDocument: LibraryBackupDocument?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var showClearConfirmation = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section("显示") {
                    Picker("外观", selection: $appearance) {
                        Text("跟随系统").tag("system")
                        Text("浅色").tag("light")
                        Text("深色").tag("dark")
                    }
                    .pickerStyle(.segmented)
                }

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

                Section("关于") {
                    LabeledContent("版本", value: "0.1.0")

                    Link(destination: URL(string: "https://www.themoviedb.org")!) {
                        Label("数据来源：TMDB", systemImage: "film.stack")
                    }

                    Text("This product uses the TMDB API but is not endorsed or certified by TMDB.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                #if DEBUG
                Section("开发者") {
                    LabeledContent("TMDB", value: AppConfiguration.isTMDBConfigured ? "已配置" : "未配置")

                    NavigationLink("Glass Lab") {
                        GlassLabView()
                    }
                }
                #endif
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
