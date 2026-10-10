import NetworkExtension
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var vpn: VPNManager

    var body: some View {
        Group {
            if model.consented {
                HomeView()
            } else {
                DisclosureView()
            }
        }
    }
}

/// الشاشة الرئيسية: حالة التجربة وزر التشغيل.
struct HomeView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var vpn: VPNManager

    private var up: Bool { vpn.isUp }

    var body: some View {
        VStack(spacing: 20) {
            Text("app_name")
                .font(.largeTitle.bold())
                .padding(.top, 24)

            if let access = model.access {
                StatusBanner(access: access)
            }

            Spacer()

            Button {
                Task { await model.toggle() }
            } label: {
                ZStack {
                    Circle()
                        .fill(up ? Color.green.opacity(0.85) : Color.gray.opacity(0.25))
                        .frame(width: 190, height: 190)
                    if model.busy || vpn.status == .connecting {
                        ProgressView().scaleEffect(1.6)
                    } else {
                        Image(systemName: "power")
                            .font(.system(size: 64, weight: .semibold))
                            .foregroundColor(up ? .white : .secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(up ? "tap_to_stop" : "tap_to_start"))

            Text(up ? "state_on" : "state_off")
                .font(.title3)

            if let failure = model.failure {
                Text(message(for: failure))
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            Text("footer_note")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
        .padding()
    }

    private func message(for failure: AppModel.Failure) -> LocalizedStringKey {
        switch failure {
        case .network: return "err_net"
        case .notConfigured: return "err_server"
        case .vpn: return "err_vpn"
        }
    }
}

struct StatusBanner: View {
    let access: AccessStatus

    var body: some View {
        let text: LocalizedStringKey = access.state == "expired"
            ? "banner_expired"
            : access.state == "trial"
                ? "banner_trial \(access.daysLeft)"
                : "banner_active"
        Text(text)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

/// إفصاح قبل أول استعمال: ماذا يمر عبر النفق وماذا نحفظ.
struct DisclosureView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("disclosure_title").font(.title.bold())
                Text("disclosure_body")
                Button {
                    model.acceptDisclosure()
                    Task { await model.refresh() }
                } label: {
                    Text("disclosure_accept")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(24)
        }
    }
}
