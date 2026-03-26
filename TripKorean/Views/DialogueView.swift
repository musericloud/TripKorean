import SwiftUI

struct DialogueListView: View {
    let store: PhraseStore
    let speechService: SpeechService

    var body: some View {
        NavigationStack {
            List(store.dialogues) { dialogue in
                NavigationLink {
                    DialogueDetailView(
                        dialogue: dialogue,
                        speechService: speechService
                    )
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: dialogue.icon)
                            .font(.title2)
                            .foregroundStyle(.blue)
                            .frame(width: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dialogue.title)
                                .font(.headline)
                            Text(dialogue.scene)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("实景对话")
        }
    }
}

struct DialogueDetailView: View {
    let dialogue: Dialogue
    let speechService: SpeechService
    @State private var revealedCount = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(dialogue.scene)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                ForEach(Array(dialogue.lines.enumerated()), id: \.element.id) { index, line in
                    if index < revealedCount {
                        DialogueBubble(line: line, speechService: speechService)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                }

                if revealedCount < dialogue.lines.count {
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            revealedCount += 1
                        }
                    } label: {
                        Label("下一句", systemImage: "chevron.down.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.top, 8)
                } else if revealedCount > 0 {
                    Button {
                        withAnimation {
                            revealedCount = 0
                        }
                    } label: {
                        Label("重新开始", systemImage: "arrow.counterclockwise.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.top, 8)
                }
            }
            .padding()
        }
        .navigationTitle(dialogue.title)
        .onAppear {
            revealedCount = 1
        }
    }
}

struct DialogueBubble: View {
    let line: DialogueLine
    let speechService: SpeechService
    @AppStorage("showPronunciation") private var showPronunciation = true
    private var isUser: Bool { line.speaker == "你" }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isUser { Spacer(minLength: 40) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(line.speaker)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(line.korean)
                            .font(.body)
                            .fontWeight(.medium)
                        Button {
                            speechService.toggleSpeak(line.korean)
                        } label: {
                            Image(systemName: speechService.isSpeaking(line.korean) ? "stop.fill" : "speaker.wave.2")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white.opacity(0.8))
                    }
                    if showPronunciation {
                        Text(line.pronunciation)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Text(line.chinese)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(12)
                .background(
                    isUser ? Color.blue : Color.gray.opacity(0.7),
                    in: RoundedRectangle(cornerRadius: 16)
                )
            }

            if !isUser { Spacer(minLength: 40) }
        }
    }
}
