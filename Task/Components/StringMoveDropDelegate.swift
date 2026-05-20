import SwiftUI
import UniformTypeIdentifiers

/// A `DropDelegate` that accepts a single string payload (e.g. a UUID or prefixed identifier)
/// and reports the drop with `DragOperation.move`, which suppresses the system's green `+` badge.
struct StringMoveDropDelegate: DropDelegate {
    let onDrop: (String) -> Bool

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: Self.acceptedTypes)
    }

    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: Self.acceptedTypes)
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
            let resolved: String? = {
                if let s = item as? String { return s }
                if let data = item as? Data, let s = String(data: data, encoding: .utf8) { return s }
                return nil
            }()
            guard let string = resolved else { return }
            DispatchQueue.main.async {
                _ = onDrop(string)
            }
        }
        return true
    }

    static let acceptedTypes: [UTType] = [.utf8PlainText, .text, .plainText]
}
