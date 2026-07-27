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

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

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

        let viewContext = container.viewContext
        viewContext.automaticallyMergesChangesFromParent = true

        // Without an explicit policy this context uses NSErrorMergePolicy,
        // which *throws* on any conflict instead of merging. That matters
        // here because OCR, auto-titling and the history pruner all write
        // from background contexts and merge into this one — a save that
        // collided with one of them would fail, and `saveContext()`
        // discards the error, so the user's edit would vanish silently.
        // Property-level merge with in-memory changes winning is the right
        // shape: background jobs only fill in derived fields, so a user's
        // own edit should never lose to them.
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // An undo manager retains every change for the life of the context.
        // Nothing here offers undo, so this is pure memory growth.
        viewContext.undoManager = nil
    }

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for i in 0..<10 {
            let newItem = ClipboardItemEntity(context: viewContext)
            newItem.id = UUID()
            newItem.date = Date().addingTimeInterval(Double(-i * 3600))
            newItem.contentType = "text"
            newItem.content = "Sample Text \(i)"
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
