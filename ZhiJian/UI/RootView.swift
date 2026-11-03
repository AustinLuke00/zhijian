import SwiftUI

/// App 导航根视图。
/// - 钥匙串无 Key（disconnected）时，fullScreenCover 展示引导流程。
/// - 连接成功后 dismiss cover 进入 TabView。
struct RootView: View {
    @Environment(ReadConnectionService.self) private var conn

    @State private var showOnboarding = false
    @State private var didCheckConnection = false

    var body: some View {
        TabView {
            ShelfView()
                .tabItem {
                    Label("书架", systemImage: "books.vertical")
                        .accessibilityLabel("书架")
                }
            QuoteListView()
                .tabItem {
                    Label("摘录", systemImage: "quote.bubble")
                        .accessibilityLabel("摘录")
                }
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                        .accessibilityLabel("设置")
                }
        }
        .tint(ZJ.accent)
        .background(ZJ.bg.ignoresSafeArea())
        .onAppear {
            guard !didCheckConnection else { return }
            didCheckConnection = true
            showOnboarding = !conn.isConnected
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
                .environment(conn)
        }
    }
}
