import SwiftUI

struct EditEntrySheet: View {
    let anime: MockAnime
    let onSave: (LibraryStatus, Int, Double?, String, Bool) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var draftProgress: Int
    @State private var status: LibraryStatus
    @State private var score: Double
    @State private var notes: String
    @State private var isFavorite: Bool

    init(
        anime: MockAnime,
        onSave: @escaping (LibraryStatus, Int, Double?, String, Bool) -> Void
    ) {
        self.anime = anime
        self.onSave = onSave
        _draftProgress = State(initialValue: anime.progress)
        _status = State(initialValue: anime.status)
        _score = State(initialValue: anime.userScore ?? 0)
        _notes = State(initialValue: anime.notes)
        _isFavorite = State(initialValue: anime.isFavorite)
    }

    private var total: Int { max(anime.total, 1) }

    var body: some View {
        NavigationStack {
            Form {
                Section("状态") {
                    Picker("状态", selection: $status) {
                        ForEach(LibraryStatus.allCases) { item in
                            Label(item.title, systemImage: item.systemImage)
                                .tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("进度") {
                    if anime.isMovie {
                        Toggle("已看完", isOn: Binding(
                            get: { draftProgress >= 1 },
                            set: { draftProgress = $0 ? 1 : 0 }
                        ))
                    } else {
                        Stepper(value: $draftProgress, in: 0...total) {
                            Text("第 \(draftProgress) 话 / 共 \(total) 话")
                        }

                        HStack {
                            Button("看到最新") {
                                draftProgress = total
                            }
                            .font(.caption.weight(.semibold))

                            Spacer()

                            Text("\(Int(fraction * 100))%")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("评分") {
                    HStack(spacing: 12) {
                        Slider(value: $score, in: 0...10, step: 0.5)
                            .tint(AppTheme.accent)

                        Text(score == 0 ? "未评分" : String(format: "%.1f", score))
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(score == 0 ? .secondary : .primary)
                            .frame(width: 48, alignment: .trailing)
                    }
                }

                Section("笔记") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 110)
                        .overlay(alignment: .topLeading) {
                            if notes.isEmpty {
                                Text("写点什么，之后再看会很有趣。")
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                Section {
                    Toggle("收藏", isOn: $isFavorite)
                }
            }
            .navigationTitle("编辑条目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(
                            status,
                            draftProgress,
                            score > 0 ? score : nil,
                            notes,
                            isFavorite
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onChange(of: status) { _, newValue in
                if newValue == .completed {
                    draftProgress = total
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return min(Double(draftProgress) / Double(total), 1)
    }
}
