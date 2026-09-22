import UIKit

/// The alerts the bucket and category screens share: naming something, and
/// deciding what happens to transactions when a bucket or category goes.
extension UIViewController {
    /// Asks for a name and hands it to `save`. A rejected name is explained,
    /// then the prompt comes back holding it so it can be corrected.
    func promptForName(title: String, name: String = "", actionTitle: String,
                       save: @escaping (String) throws -> Void) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addTextField { field in
            field.text = name
            field.placeholder = "Name"
            field.autocapitalizationType = .sentences
            field.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        let action = UIAlertAction(title: actionTitle, style: .default) { [weak self, weak alert] _ in
            let entered = alert?.textFields?.first?.text ?? ""
            do {
                try save(entered)
            } catch {
                self?.showCategoryError(error) {
                    self?.promptForName(title: title, name: entered, actionTitle: actionTitle, save: save)
                }
            }
        }
        alert.addAction(action)
        alert.preferredAction = action
        self.present(alert, animated: true)
    }

    func showCategoryError(_ error: Error, then: (() -> Void)? = nil) {
        let alert = UIAlertController(title: "Couldn’t save that change", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in then?() })
        self.present(alert, animated: true)
    }

    /// Deletes the category once the user says where its transactions go:
    /// another category, or uncategorised.
    func confirmDeletingCategory(_ category: TransactionCategory, from sourceView: UIView?,
                                 store: CategoryStore = .shared, transactionStore: TransactionStore = .shared,
                                 completion: @escaping () -> Void) {
        let uses = transactionStore.transactions().filter { transaction in
            transaction.allocations.contains { $0.path.categoryID == category.id }
        }.count
        let delete: (TransactionCategory.ID?) -> Void = { [weak self] destination in
            do {
                try store.deleteCategory(category.id, movingTransactionsTo: destination, transactionStore: transactionStore)
                completion()
            } catch {
                self?.showCategoryError(error)
            }
        }
        let sheet = UIAlertController(title: "Delete “\(category.name)”?", message: nil, preferredStyle: .actionSheet)
        if uses == 0 {
            sheet.message = category.subcategories.isEmpty ? nil : "Its subcategories are deleted with it."
            sheet.addAction(UIAlertAction(title: "Delete Category", style: .destructive) { _ in delete(nil) })
        } else {
            sheet.message = "\(Self.transactionCount(uses)) \(uses == 1 ? "uses" : "use") it. Move them to another category, or leave them uncategorised."
            for bucket in store.tree().buckets {
                for other in bucket.categories where other.id != category.id {
                    sheet.addAction(UIAlertAction(title: "\(bucket.name) › \(other.name)", style: .default) { _ in delete(other.id) })
                }
            }
            sheet.addAction(UIAlertAction(title: "Leave Uncategorised", style: .destructive) { _ in delete(nil) })
        }
        self.presentSheet(sheet, from: sourceView)
    }

    /// Deletes the bucket. Its categories either move to another bucket,
    /// keeping their transactions, or go with it.
    func confirmDeletingBucket(_ bucket: Bucket, from sourceView: UIView?,
                               store: CategoryStore = .shared, transactionStore: TransactionStore = .shared,
                               completion: @escaping () -> Void) {
        let delete: (Bucket.ID?) -> Void = { [weak self] destination in
            do {
                try store.deleteBucket(bucket.id, movingCategoriesTo: destination, transactionStore: transactionStore)
                completion()
            } catch {
                self?.showCategoryError(error)
            }
        }
        let sheet = UIAlertController(title: "Delete “\(bucket.name)”?", message: nil, preferredStyle: .actionSheet)
        if bucket.categories.isEmpty {
            sheet.addAction(UIAlertAction(title: "Delete Bucket", style: .destructive) { _ in delete(nil) })
        } else {
            let categoryIDs = Set(bucket.categories.map(\.id))
            let uses = transactionStore.transactions().filter { transaction in
                transaction.allocations.contains { categoryIDs.contains($0.path.categoryID) }
            }.count
            let count = bucket.categories.count
            var message = "Move its \(count == 1 ? "category" : "\(count) categories") to another bucket, or delete \(count == 1 ? "it" : "them") too."
            if uses > 0 {
                message += " Deleting leaves \(Self.transactionCount(uses)) uncategorised."
            }
            sheet.message = message
            for other in store.tree().buckets where other.id != bucket.id {
                sheet.addAction(UIAlertAction(title: "Move to \(other.name)", style: .default) { _ in delete(other.id) })
            }
            sheet.addAction(UIAlertAction(
                title: count == 1 ? "Delete Category Too" : "Delete Categories Too", style: .destructive
            ) { _ in delete(nil) })
        }
        self.presentSheet(sheet, from: sourceView)
    }

    private func presentSheet(_ sheet: UIAlertController, from sourceView: UIView?) {
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        // Action sheets become popovers on iPad and need an anchor.
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = sourceView ?? self.view
            if sourceView == nil {
                popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
        }
        self.present(sheet, animated: true)
    }

    private static func transactionCount(_ count: Int) -> String {
        count == 1 ? "1 transaction" : "\(count.formatted()) transactions"
    }
}
