import SwiftUI

struct SettingsView: View {
    @AppStorage("speechRate") private var speechRate: Double = 0.85
    @AppStorage("showPronunciation") private var showPronunciation = true

    var body: some View {
        NavigationStack {
            Form {
                Section("语音设置") {
                    VStack(alignment: .leading) {
                        Text("语速：\(speedLabel)")
                        Slider(value: $speechRate, in: 0.3...1.0, step: 0.05)
                    }
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
