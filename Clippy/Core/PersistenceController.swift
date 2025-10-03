//
//  PersistenceController.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 22.09.2025.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Clippy") // Veri modelinizin adıyla eşleşmeli
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Otomatik ve hafif veri modeli geçişlerini (migration) etkinleştir.
        // Bu, gelecekte veri modeline yeni bir özellik eklendiğinde, Core Data'nın
        // veritabanını otomatik olarak ve veri kaybı olmadan güncellemesini sağlar.
        let description = container.persistentStoreDescriptions.first
        description?.shouldInferMappingModelAutomatically = true
        description?.shouldMigrateStoreAutomatically = true
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for i in 0..<10 {
            let newItem = ClipboardItemEntity(context: viewContext)
            newItem.id = UUID()
            newItem.date = Date().addingTimeInterval(Double(-i * 3600))
            newItem.contentType = "text"
            newItem.content = "Örnek Metin \(i)"
            newItem.isFavorite = (i % 3 == 0)
            newItem.isCode = (i % 4 == 0)
        }
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()
}