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
        container = NSPersistentContainer(name: "Clippy")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("###< Persistence Error >### Failed to retrieve a persistent store description.")
        }
        description.shouldInferMappingModelAutomatically = true
        description.shouldMigrateStoreAutomatically = true

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
            newItem.isPinned = (i == 0)
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
