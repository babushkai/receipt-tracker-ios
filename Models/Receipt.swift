//
//  Receipt.swift
//  ReceiptTracker
//
//  Receipt data model
//

import Foundation
import CoreData

// MARK: - Receipt Entity
@objc(Receipt)
public class Receipt: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var date: Date
    @NSManaged public var merchantName: String?
    @NSManaged public var totalAmount: Double
    @NSManaged public var category: String?
    @NSManaged public var imageData: Data?
    @NSManaged public var notes: String?
    @NSManaged public var currency: String
    @NSManaged public var items: NSSet?
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    
    // Computed properties
    var categoryEnum: ExpenseCategory {
        get {
            ExpenseCategory(rawValue: category ?? "") ?? .other
        }
        set {
            category = newValue.rawValue
        }
    }
    
    var itemsArray: [ReceiptItem] {
        let set = items as? Set<ReceiptItem> ?? []
        return set.sorted { $0.order < $1.order }
    }
}

extension Receipt {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Receipt> {
        return NSFetchRequest<Receipt>(entityName: "Receipt")
    }
}

// MARK: - Receipt Item Entity
@objc(ReceiptItem)
public class ReceiptItem: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var price: Double
    @NSManaged public var quantity: Int16
    @NSManaged public var order: Int16
    @NSManaged public var receipt: Receipt?
}

extension ReceiptItem {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ReceiptItem> {
        return NSFetchRequest<ReceiptItem>(entityName: "ReceiptItem")
    }
}

// MARK: - Expense Category Enum
enum ExpenseCategory: String, CaseIterable, Identifiable {
    case food = "Food & Dining"
    case groceries = "Groceries"
    case transportation = "Transportation"
    case utilities = "Utilities"
    case entertainment = "Entertainment"
    case shopping = "Shopping"
    case healthcare = "Healthcare"
    case education = "Education"
    case travel = "Travel"
    case housing = "Housing"
    case other = "Other"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .groceries: return "cart.fill"
        case .transportation: return "car.fill"
        case .utilities: return "bolt.fill"
        case .entertainment: return "tv.fill"
        case .shopping: return "bag.fill"
        case .healthcare: return "cross.case.fill"
        case .education: return "book.fill"
        case .travel: return "airplane"
        case .housing: return "house.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .food: return "orange"
        case .groceries: return "green"
        case .transportation: return "blue"
        case .utilities: return "yellow"
        case .entertainment: return "purple"
        case .shopping: return "pink"
        case .healthcare: return "red"
        case .education: return "indigo"
        case .travel: return "cyan"
        case .housing: return "brown"
        case .other: return "gray"
        }
    }
}

// MARK: - Receipt DTO (for SwiftUI previews and non-CoreData usage)
struct ReceiptDTO: Identifiable {
    let id: UUID
    let date: Date
    let merchantName: String
    let totalAmount: Double
    let category: ExpenseCategory
    let currency: String
    let items: [ReceiptItemDTO]
    
    init(from receipt: Receipt) {
        self.id = receipt.id
        self.date = receipt.date
        self.merchantName = receipt.merchantName ?? "Unknown"
        self.totalAmount = receipt.totalAmount
        self.category = receipt.categoryEnum
        self.currency = receipt.currency
        self.items = receipt.itemsArray.map { ReceiptItemDTO(from: $0) }
    }
}

struct ReceiptItemDTO: Identifiable {
    let id: UUID
    let name: String
    let price: Double
    let quantity: Int
    
    init(from item: ReceiptItem) {
        self.id = item.id
        self.name = item.name
        self.price = item.price
        self.quantity = Int(item.quantity)
    }
}

