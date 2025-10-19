//
//  PersistenceController.swift
//  ReceiptTracker
//
//  Core Data persistence layer
//

import CoreData
import Foundation

extension Notification.Name {
    static let receiptsDidChange = Notification.Name("receiptsDidChange")
}

struct PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "ReceiptDataModel")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // MARK: - Preview Support
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext
        
        // Create sample data
        for i in 0..<10 {
            let receipt = Receipt(context: viewContext)
            receipt.id = UUID()
            receipt.date = Date().addingTimeInterval(Double(-i * 86400))
            receipt.merchantName = ["Whole Foods", "Starbucks", "Shell Gas", "Target", "Amazon"][i % 5]
            receipt.totalAmount = Double.random(in: 10...150)
            receipt.category = ExpenseCategory.allCases[i % ExpenseCategory.allCases.count].rawValue
            receipt.currency = "USD"
            receipt.createdAt = Date()
            receipt.updatedAt = Date()
        }
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        
        return controller
    }()
    
    // MARK: - CRUD Operations
    func saveContext() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("Error saving context: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    func createReceipt(
        date: Date,
        merchantName: String?,
        totalAmount: Double,
        category: ExpenseCategory,
        imageData: Data?,
        notes: String?,
        items: [ReceiptItemData]
    ) -> Receipt {
        let context = container.viewContext
        let receipt = Receipt(context: context)
        receipt.id = UUID()
        receipt.date = date
        receipt.merchantName = merchantName
        receipt.totalAmount = totalAmount
        receipt.categoryEnum = category
        receipt.imageData = imageData
        receipt.notes = notes
        receipt.currency = "USD"
        receipt.createdAt = Date()
        receipt.updatedAt = Date()
        
        for (index, itemData) in items.enumerated() {
            let item = ReceiptItem(context: context)
            item.id = UUID()
            item.name = itemData.name
            item.price = itemData.price
            item.quantity = Int16(itemData.quantity)
            item.order = Int16(index)
            item.receipt = receipt
        }
        
        saveContext()
        
        // Notify observers that receipts have changed
        NotificationCenter.default.post(name: .receiptsDidChange, object: nil)
        
        return receipt
    }
    
    func deleteReceipt(_ receipt: Receipt) {
        let context = container.viewContext
        context.delete(receipt)
        saveContext()
        
        // Notify observers that receipts have changed
        NotificationCenter.default.post(name: .receiptsDidChange, object: nil)
    }
    
    func fetchReceipts(
        startDate: Date? = nil,
        endDate: Date? = nil,
        category: ExpenseCategory? = nil
    ) -> [Receipt] {
        let request: NSFetchRequest<Receipt> = Receipt.fetchRequest()
        var predicates: [NSPredicate] = []
        
        if let startDate = startDate {
            predicates.append(NSPredicate(format: "date >= %@", startDate as NSDate))
        }
        
        if let endDate = endDate {
            predicates.append(NSPredicate(format: "date <= %@", endDate as NSDate))
        }
        
        if let category = category {
            predicates.append(NSPredicate(format: "category == %@", category.rawValue))
        }
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Receipt.date, ascending: false)]
        
        do {
            return try container.viewContext.fetch(request)
        } catch {
            print("Error fetching receipts: \(error)")
            return []
        }
    }
}

// MARK: - Helper Structs
struct ReceiptItemData {
    let name: String
    let price: Double
    let quantity: Int
}

