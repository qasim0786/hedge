import AppKit
import SwiftUI

enum Support {
    static let studio = "Technospike IT Solutions"
    static let site = URL(string: "https://technospike.com/")!
    static let mail = "info@technospike.com"
    static let phone = "+91 84277 22113"
    static let address = "Plot No. 1301, Sector 82, JLPL Industrial Area, Mohali, Punjab"

    static func openSite() {
        NSWorkspace.shared.open(site)
    }

    static func openMail() {
        let subject = "Hedge donation".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Hedge"
        guard let url = URL(string: "mailto:\(mail)?subject=\(subject)") else { return }
        NSWorkspace.shared.open(url)
    }

    static func openPhone() {
        guard let url = URL(string: "tel:+918427722113") else { return }
        NSWorkspace.shared.open(url)
    }

    static let accounts: [BankAccount] = [
        BankAccount(bank: "National Bank of Pakistan", title: "Muhammad qasim Malik", iban: "PK32NBPA0505003166863228", swift: "NBPAPKKA"),
        BankAccount(bank: "United Bank Limited", title: "Muhammad QASIM MALIK", iban: "PK54UNIL0109000291588122", swift: "UNILPKKA"),
        BankAccount(bank: "JS Bank (Zindagi)", title: "Muhammad Qasim Malik", iban: "PK69JSBL9999903145098262", swift: "JSBLPKKA")
    ]
}

struct BankAccount: Identifiable {
    var id: String { iban }
    let bank: String
    let title: String
    let iban: String
    let swift: String
}

struct DonateOverlay: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { model.showDonate = false }

            VStack(alignment: .leading, spacing: 18) {
                Text("Donate")
                    .font(Theme.serif(34))
                    .foregroundStyle(Theme.ink)
                Text("Hedge is free. A gift is optional. Send PKR to one account, and copy the account title exactly as it is written.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.mute)
                    .fixedSize(horizontal: false, vertical: true)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Support.accounts) { account in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(account.bank)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Theme.ink)
                                detail("Account title", account.title)
                                detail("IBAN", account.iban)
                                detail("SWIFT", account.swift)
                            }
                        }
                    }
                }
                .frame(maxHeight: 360)
                .textSelection(.enabled)

                HStack(spacing: 10) {
                    Button("Website") { Support.openSite() }
                        .buttonStyle(GhostButtonStyle())
                    Button("Email") { Support.openMail() }
                        .buttonStyle(GhostButtonStyle())
                    Button("Call") { Support.openPhone() }
                        .buttonStyle(GhostButtonStyle())
                    Spacer()
                    Button("Done") { model.showDonate = false }
                        .buttonStyle(MossButtonStyle())
                        .keyboardShortcut(.cancelAction)
                }
            }
            .padding(28)
            .frame(width: 560)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Theme.line, lineWidth: 1)
            }
        }
    }

    private func detail(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(Theme.mute)
            Text(value)
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
