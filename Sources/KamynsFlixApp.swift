import SwiftUI
import WebKit

@main
struct KamynsFlixApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

private struct RootView: View {
    @State private var authorized = false
    @State private var savedLicense = UserDefaults.standard.string(forKey: "kamynsSavedLicense") ?? ""

    var body: some View {
        ZStack {
            if authorized {
                WebContainer(url: URL(string: "https://kamynsflix.edgeone.app/")!)
                    .ignoresSafeArea()
            } else {
                LoginView(savedLicense: savedLicense) { license in
                    if let license, !license.isEmpty {
                        UserDefaults.standard.set(license, forKey: "kamynsSavedLicense")
                    }
                    authorized = true
                }
            }
        }
        .onAppear {
            savedLicense = UserDefaults.standard.string(forKey: "kamynsSavedLicense") ?? ""
        }
    }
}

private enum LoginMode {
    case license
    case admin
}

private struct LoginView: View {
    let savedLicense: String
    let onAuthorized: (String?) -> Void

    @State private var mode: LoginMode = .license
    @State private var input = ""
    @State private var status = ""
    @State private var isError = false
    @State private var isLoading = false

    private let keyAuthName = "Kamyns movie nights"
    private let keyAuthOwnerId = "4E4aS4hWNC"
    private let keyAuthVersion = "1.0"
    private let adminPassword = "gekyume"

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 18) {
                    Spacer(minLength: max(24, geometry.size.height * 0.08))

                    LogoMark(size: geometry.size.width < 420 ? 132 : 160)

                    Text("Kamyns flix 2.0")
                        .font(.system(size: geometry.size.width < 420 ? 34 : 42, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(mode == .admin ? "Admin access" : "Enter your license key")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.68))

                    HStack(spacing: 10) {
                        ModeButton(title: "LICENSE", selected: mode == .license) {
                            mode = .license
                            input = ""
                            status = ""
                        }
                        ModeButton(title: "ADMIN", selected: mode == .admin) {
                            mode = .admin
                            input = ""
                            status = ""
                        }
                    }

                    Group {
                        if mode == .admin {
                            SecureField("Admin password", text: $input)
                        } else {
                            TextField("License key", text: $input)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                        }
                    }
                    .font(.system(size: 22, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .tint(Color(red: 0.0, green: 0.76, blue: 0.55))
                    .padding(.horizontal, 16)
                    .frame(height: 58)
                    .background(Color(red: 0.09, green: 0.09, blue: 0.12))

                    Button(action: attemptLogin) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(mode == .admin ? "ADMIN LOGIN" : "LOGIN")
                                .font(.system(size: 20, weight: .black))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(Color(red: 0.88, green: 0.03, blue: 0.08))
                        .foregroundColor(.white)
                    }
                    .disabled(isLoading)
                    .opacity(isLoading ? 0.72 : 1.0)

                    if !status.isEmpty {
                        Text(status)
                            .font(.system(size: 16, weight: .bold))
                            .multilineTextAlignment(.center)
                            .foregroundColor(isError ? Color(red: 1.0, green: 0.42, blue: 0.42) : Color.white.opacity(0.68))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 24)
                }
                .frame(width: min(460, geometry.size.width * 0.86))
                .frame(maxWidth: .infinity)
                .minHeight(geometry.size.height)
            }
            .background(Color(red: 0.02, green: 0.02, blue: 0.03).ignoresSafeArea())
        }
        .onAppear {
            if !savedLicense.isEmpty && input.isEmpty {
                input = savedLicense
                Task { await attemptLicense(savedLicense) }
            }
        }
    }

    private func attemptLogin() {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            setStatus(mode == .admin ? "Enter the admin password to continue." : "Enter a license key to continue.", error: true)
            return
        }

        if mode == .admin {
            if value == adminPassword {
                onAuthorized(nil)
            } else {
                setStatus("Incorrect admin password.", error: true)
            }
            return
        }

        Task { await attemptLicense(value) }
    }

    @MainActor
    private func setStatus(_ message: String, error: Bool) {
        status = message
        isError = error
    }

    private func attemptLicense(_ license: String) async {
        await MainActor.run {
            isLoading = true
            setStatus("Signing in...", error: false)
        }

        do {
            let initResponse = try await keyAuthRequest([
                "type": "init",
                "ver": keyAuthVersion,
                "name": keyAuthName,
                "ownerid": keyAuthOwnerId,
                "hash": "undefined",
                "token": "undefined",
                "thash": "undefined"
            ])

            guard initResponse.success == true else {
                throw LoginError.message(initResponse.message ?? "KeyAuth initialization failed.")
            }

            guard let sessionId = initResponse.sessionid, !sessionId.isEmpty else {
                throw LoginError.message("KeyAuth did not return a session.")
            }

            let loginResponse = try await keyAuthRequest([
                "type": "license",
                "key": license,
                "sessionid": sessionId,
                "name": keyAuthName,
                "ownerid": keyAuthOwnerId,
                "hwid": hwid(for: license),
                "code": ""
            ])

            guard loginResponse.success == true else {
                throw LoginError.message(loginResponse.message ?? "License login failed.")
            }

            await MainActor.run {
                isLoading = false
                onAuthorized(license)
            }
        } catch {
            await MainActor.run {
                isLoading = false
                UserDefaults.standard.removeObject(forKey: "kamynsSavedLicense")
                if let loginError = error as? LoginError {
                    setStatus(loginError.localizedDescription, error: true)
                } else {
                    setStatus("Could not reach KeyAuth. Check your connection and try again.", error: true)
                }
            }
        }
    }

    private func keyAuthRequest(_ params: [String: String]) async throws -> KeyAuthResponse {
        var components = URLComponents(string: "https://keyauth.win/api/1.3/")!
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }

        var request = URLRequest(url: components.url!)
        request.setValue("KamynsFlix2-iOS/1.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(KeyAuthResponse.self, from: data)
    }

    private func hwid(for license: String) -> String {
        let trimmed = license.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = "kamyns-flix-2.0-\(trimmed)"
        return value.count >= 20 ? value : "kamyns-flix-2.0-ios-device"
    }
}

private struct KeyAuthResponse: Decodable {
    let success: Bool?
    let message: String?
    let sessionid: String?
}

private enum LoginError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let message):
            return message
        }
    }
}

private struct ModeButton: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .black))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(selected ? Color(red: 0.88, green: 0.03, blue: 0.08) : Color(red: 0.09, green: 0.09, blue: 0.12))
                .foregroundColor(selected ? .white : Color.white.opacity(0.68))
        }
    }
}

private struct LogoMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.16)
                .fill(LinearGradient(colors: [Color.black, Color(red: 0.09, green: 0.0, blue: 0.0)], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: size * 0.16).stroke(Color.red.opacity(0.22), lineWidth: 1))

            Text("K")
                .font(.system(size: size * 0.62, weight: .black, design: .rounded))
                .foregroundColor(Color(red: 0.92, green: 0.02, blue: 0.07))
                .offset(x: -size * 0.05, y: -size * 0.05)

            Image(systemName: "play.fill")
                .font(.system(size: size * 0.2, weight: .bold))
                .foregroundColor(.white)
                .shadow(radius: 6)

            VStack(spacing: 0) {
                Spacer()
                Text("KAMYNS")
                    .font(.system(size: size * 0.09, weight: .black))
                    .foregroundColor(.white)
                Text("FLIX 2.0")
                    .font(.system(size: size * 0.08, weight: .black))
                    .foregroundColor(Color(red: 0.92, green: 0.02, blue: 0.07))
                    .padding(.bottom, size * 0.08)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: Color.red.opacity(0.22), radius: 24, x: 0, y: 12)
    }
}

private struct WebContainer: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}

private extension View {
    func minHeight(_ value: CGFloat) -> some View {
        frame(minHeight: value)
    }
}
