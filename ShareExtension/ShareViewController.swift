import UIKit
import UniformTypeIdentifiers

/// Share extensions cannot reliably launch their containing app. Queue the URL in
/// the signed App Group and let the app consume it on its next foreground entry.
final class ShareViewController: UIViewController {
    private let status = UILabel()
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let title = UILabel(); title.text = "Keep this page."; title.font = .systemFont(ofSize: 30, weight: .bold)
        status.text = "Finding the website address…"; status.numberOfLines = 0; status.textColor = .secondaryLabel
        let done = UIButton(type: .system); done.setTitle("Done", for: .normal); done.addTarget(self, action: #selector(close), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [title, status, done]); stack.axis = .vertical; stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28), stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28), stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)])
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        guard let provider = items.flatMap({ $0.attachments ?? [] }).first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }) else {
            status.text = "Share a website link from Safari to save it here."; return
        }
        provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, _ in
            let url = item as? URL
            DispatchQueue.main.async {
                guard let url, ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil,
                      url.user == nil, url.password == nil,
                      let group = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String,
                      let defaults = UserDefaults(suiteName: group) else {
                    self?.status.text = "This link could not be saved. Copy its address into Easy Capture instead."; return
                }
                defaults.set(url.absoluteString, forKey: "pendingCaptureURL")
                self?.status.text = "Link saved. Open Easy Capture to choose your settings and capture the page."
            }
        }
    }
    @objc private func close() { extensionContext?.completeRequest(returningItems: nil) }
}
