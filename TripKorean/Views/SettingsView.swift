import SwiftUI
import AVFoundation

struct SettingsView: View {
    let speechService: SpeechService

    @AppStorage("speechRate") private var speechRate: Double = 0.85
    @AppStorage("showPronunciation") private var showPronunciation = true
    @AppStorage("conversationAutoSpeak") private var conversationAutoSpeak = true
    @AppStorage("voiceId.ko-KR") private var koreanVoiceId = ""
    @AppStorage("voiceId.zh-CN") private var chineseVoiceId = ""
    @Environment(\.dismiss) private var dismiss

    @State private var koreanVoices: [AVSpeechSynthesisVoice] = []
    @State private var chineseVoices: [AVSpeechSynthesisVoice] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("语音设置") {
                    VStack(alignment: .leading) {
                        Text("语速：\(speedLabel)")
                        Slider(value: $speechRate, in: 0.3...1.0, step: 0.05)
                    }
                    Toggle("对话翻译自动朗读", isOn: $conversationAutoSpeak)
                }

                Section {
                    voicePicker(title: "韩语语音", voices: koreanVoices, selection: $koreanVoiceId)
                    previewButton(title: "试听韩语", text: "안녕하세요, 만나서 반갑습니다.", language: "ko-KR")

                    voicePicker(title: "中文语音", voices: chineseVoices, selection: $chineseVoiceId)
                    previewButton(title: "试听中文", text: "你好，很高兴认识你。", language: "zh-CN")
                } header: {
                    Text("朗读语音")
                } footer: {
                    Text("想要更自然的发音，可在系统「设置 → 辅助功能 → 朗读内容 → 声音」中下载「增强 / 高级」版语音（如 Yuna 增强版）。保持「自动」将始终使用已安装的最高音质。")
                }

                Section("显示设置") {
                    Toggle("显示罗马音标注", isOn: $showPronunciation)
                }

                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("开发者")
                        Spacer()
                        Text("TripKorean Team")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .onAppear(perform: reloadVoices)
            .onReceive(NotificationCenter.default.publisher(for: AVSpeechSynthesizer.availableVoicesDidChangeNotification)) { _ in
                reloadVoices()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                reloadVoices()
            }
        }
    }

    private func voicePicker(title: String, voices: [AVSpeechSynthesisVoice], selection: Binding<String>) -> some View {
        Picker(title, selection: selection) {
            Text("自动（最高音质）").tag("")
            ForEach(voices, id: \.identifier) { voice in
                Text("\(voice.name) · \(SpeechService.qualityLabel(voice))")
                    .tag(voice.identifier)
            }
        }
    }

    private func previewButton(title: String, text: String, language: String) -> some View {
        Button {
            speechService.toggleSpeak(text, language: language)
        } label: {
            Label(
                speechService.isSpeaking(text) ? "停止" : title,
                systemImage: speechService.isSpeaking(text) ? "stop.circle" : "play.circle"
            )
        }
    }

    private func reloadVoices() {
        koreanVoices = SpeechService.installedVoices(for: "ko-KR")
        chineseVoices = SpeechService.installedVoices(for: "zh-CN")
        // 之前选择的语音被用户从系统中删除时，回退到自动
        if !koreanVoiceId.isEmpty, !koreanVoices.contains(where: { $0.identifier == koreanVoiceId }) {
            koreanVoiceId = ""
        }
        if !chineseVoiceId.isEmpty, !chineseVoices.contains(where: { $0.identifier == chineseVoiceId }) {
            chineseVoiceId = ""
        }
    }

    private var speedLabel: String {
        switch speechRate {
        case ..<0.5: "慢速"
        case 0.5..<0.75: "较慢"
        case 0.75..<0.9: "正常"
        case 0.9..<1.0: "较快"
        default: "快速"
        }
    }
}
