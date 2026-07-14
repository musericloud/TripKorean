import SwiftUI

// MARK: - 发音学习首页

struct HangulHomeView: View {
    let speechService: SpeechService
    @State private var showSettings = false

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    syllableStructureCard

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(HangulData.groups) { group in
                            NavigationLink {
                                HangulGroupView(group: group, speechService: speechService)
                            } label: {
                                HangulGroupCard(group: group)
                            }
                            .buttonStyle(.plain)
                        }

                        NavigationLink {
                            SyllableChartView(speechService: speechService)
                        } label: {
                            chartCard
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("发音入门")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(speechService: speechService)
            }
        }
    }

    /// 音节结构示意卡片：한 = ㅎ + ㅏ + ㄴ
    private var syllableStructureCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("韩文字是拼出来的", systemImage: "puzzlepiece.fill")
                .font(.headline)

            Text("每个韩文字都是一个音节，由「辅音 + 元音（+ 收音）」拼合而成。学会 40 个字母，就能读出所有韩文。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                syllablePart("한", color: .blue, caption: "字")
                Text("=")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                syllablePart("ㅎ", color: .orange, caption: "辅音 h")
                Text("+")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                syllablePart("ㅏ", color: .teal, caption: "元音 a")
                Text("+")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                syllablePart("ㄴ", color: .green, caption: "收音 n")

                Spacer()

                Button {
                    speechService.toggleSpeakHangul("한")
                } label: {
                    Image(systemName: "speaker.wave.2.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func syllablePart(_ text: String, color: Color, caption: String) -> some View {
        VStack(spacing: 4) {
            Text(text)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "tablecells.fill")
                    .font(.title2)
                    .foregroundStyle(.pink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Text("音节拼读表")
                .font(.headline)
            Text("가나다 全表跟读")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct HangulGroupCard: View {
    let group: HangulGroup

    private var preview: String {
        group.letters.prefix(5).map(\.symbol).joined(separator: " ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: group.icon)
                    .font(.title2)
                    .foregroundStyle(group.color)
                Spacer()
                Text(group.subtitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(group.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(group.color.opacity(0.12), in: Capsule())
            }
            Text(group.title)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(preview)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - 字母分组页

struct HangulGroupView: View {
    let group: HangulGroup
    let speechService: SpeechService
    @State private var selectedIndex: Int?

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(group.intro)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(group.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(group.letters.enumerated()), id: \.element.id) { index, letter in
                        Button {
                            selectedIndex = index
                            speechService.speakHangul(letter.soundText)
                        } label: {
                            VStack(spacing: 4) {
                                Text(letter.symbol)
                                    .font(.system(size: 34, weight: .bold))
                                    .foregroundStyle(.primary)
                                Text(letter.roman)
                                    .font(.caption)
                                    .foregroundStyle(group.color)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 76)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("点击字母听发音，再点开详情看要领和例词")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(group.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(
            get: { selectedIndex != nil },
            set: { if !$0 { selectedIndex = nil } }
        )) {
            if let index = selectedIndex {
                HangulLetterDetailView(
                    group: group,
                    index: index,
                    speechService: speechService,
                    onIndexChange: { selectedIndex = $0 }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

// MARK: - 字母详情

struct HangulLetterDetailView: View {
    let group: HangulGroup
    let index: Int
    let speechService: SpeechService
    let onIndexChange: (Int) -> Void

    private var letter: HangulLetter { group.letters[index] }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                navButton(systemImage: "chevron.left", enabled: index > 0) {
                    onIndexChange(index - 1)
                    speechService.speakHangul(group.letters[index - 1].soundText)
                }

                Spacer()

                VStack(spacing: 6) {
                    Text(letter.symbol)
                        .font(.system(size: 88, weight: .bold))
                        .foregroundStyle(group.color)

                    if let name = letter.name {
                        Text(name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text(letter.roman)
                        .font(.headline)
                        .foregroundStyle(group.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(group.color.opacity(0.12), in: Capsule())
                }

                Spacer()

                navButton(systemImage: "chevron.right", enabled: index < group.letters.count - 1) {
                    onIndexChange(index + 1)
                    speechService.speakHangul(group.letters[index + 1].soundText)
                }
            }

            Button {
                speechService.speakHangul(letter.soundText)
            } label: {
                Label("听发音 \(letter.soundText)", systemImage: "speaker.wave.2.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(group.color)

            VStack(alignment: .leading, spacing: 12) {
                Label(letter.hint, systemImage: "mouth.fill")
                    .font(.subheadline)

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(letter.exampleWord)
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("\(letter.exampleRoman) · \(letter.exampleMeaning)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        speechService.toggleSpeakHangul(letter.exampleWord)
                    } label: {
                        Image(systemName: speechService.isSpeaking(letter.exampleWord) ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(group.color)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))

            Spacer()
        }
        .padding()
        .padding(.top, 12)
        .presentationBackground(Color(.systemGroupedBackground))
    }

    private func navButton(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2)
                .fontWeight(.semibold)
                .frame(width: 44, height: 44)
                .background(Color(.secondarySystemGroupedBackground), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
    }
}

// MARK: - 音节拼读表

struct SyllableChartView: View {
    let speechService: SpeechService
    @State private var selected: String?

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                GridRow {
                    Text("辅\\元")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(width: 52, height: 44)

                    ForEach(HangulData.chartMedials, id: \.symbol) { medial in
                        VStack(spacing: 0) {
                            Text(medial.symbol)
                                .font(.headline)
                            Text(medial.roman)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 52, height: 44)
                        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    }
                }

                ForEach(HangulData.chartInitials, id: \.symbol) { initial in
                    GridRow {
                        Button {
                            let row = HangulData.chartMedials
                                .map { HangulData.syllable(initial: initial.index, medial: $0.index) }
                                .joined(separator: ", ")
                            speechService.speak(row)
                        } label: {
                            VStack(spacing: 0) {
                                Text(initial.symbol)
                                    .font(.headline)
                                Text(initial.roman.isEmpty ? "-" : initial.roman)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 52, height: 52)
                            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)

                        ForEach(HangulData.chartMedials, id: \.symbol) { medial in
                            let syllable = HangulData.syllable(initial: initial.index, medial: medial.index)
                            Button {
                                selected = syllable
                                speechService.speakHangul(syllable)
                            } label: {
                                VStack(spacing: 1) {
                                    Text(syllable)
                                        .font(.system(size: 20, weight: .semibold))
                                    Text(KoreanRomanizer.romanize(syllable))
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 52, height: 52)
                                .background(
                                    selected == syllable ? Color.blue.opacity(0.2) : Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selected == syllable ? Color.blue : .clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("音节拼读表")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Text("点击音节听发音 · 点击左侧辅音朗读整行")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
        }
    }
}
