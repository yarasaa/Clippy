## Clippy Teknik Dokümantasyonu

Bu doküman, Clippy uygulamasının temel mekanizmalarının (veri saklama, pano izleme, yapıştırma işlemleri) arka planda nasıl çalıştığını teknik olarak açıklamaktadır.

### 1. Veri Saklama (Persistence)

Uygulama, verileri verimli bir şekilde saklamak ve yönetmek için Apple'ın **Core Data** çerçevesini kullanır. Bu, JSON tabanlı eski sisteme göre çok daha yüksek performans ve ölçeklenebilirlik sağlar.

#### a. Veri Konumu

- **Core Data Veritabanı:** Tüm pano öğelerinin meta verileri (metin içeriği, favori durumu, oluşturulma tarihi vb.) bir SQLite veritabanı dosyasında tutulur.
  - **Dosya Yolu:** `~/Library/Application Support/Clippy/Clippy.sqlite`
- **Resim Dosyaları:** Kopyalanan resimler, performansı artırmak ve JSON dosyasını küçük tutmak için ayrı dosyalar olarak saklanır. JSON dosyasında sadece bu resimlerin dosya adları referans olarak tutulur.
  - **Klasör Yolu:** `~/Library/Application Support/Clippy/Images/`

#### b. Veri Modeli (`Clippy.xcdatamodeld`)

Veri modeli, `ClipboardItemEntity` adında tek bir varlık (entity) içerir. Bu varlık, kopyalanan bir öğeyi temsil eder ve aşağıdaki özelliklere (attributes) sahiptir:

- `id` (UUID): Öğenin benzersiz kimliği.
- `date` (Date): Öğenin kopyalandığı tarih.
- `isFavorite` (Boolean): Öğenin favori olarak işaretlenip işaretlenmediğini belirtir.
- `isPinned` (Boolean): Öğenin listenin en üstüne sabitlenip sabitlenmediğini belirtir.
- `isCode` (Boolean): Öğenin kod olarak algılanıp algılanmadığını belirtir.
- `sourceAppName` (String, Opsiyonel): Öğenin kopyalandığı kaynak uygulamanın adı.
- `sourceAppBundleIdentifier` (String, Opsiyonel): Kaynak uygulamanın paket kimliği (ikonu bulmak için kullanılır).
- `contentType` (String): İçeriğin türünü belirtir ("text" veya "image").
- `content` (String): Metin içeriğini veya resim dosyasının adını tutar.
- `detectedDate` (Date, Opsiyonel): Metin içinde algılanan bir tarih varsa, bu tarihi saklar.

#### c. Core Data Mimarisi (`PersistenceController.swift`)

`PersistenceController`, Core Data yığınını (stack) kuran ve yöneten merkezi yapıdır.

- **`NSPersistentContainer`:** Uygulama başlatıldığında, `Clippy` veri modelini kullanarak bir container oluşturur.
- **`viewContext`:** SwiftUI görünümlerinin ve `ClipboardMonitor`'un veri okuma/yazma işlemleri için kullandığı ana `NSManagedObjectContext`'i sağlar.
- **`automaticallyMergesChangesFromParent`:** Arka planda yapılan değişikliklerin ana `context` ile otomatik olarak birleştirilmesini sağlar.

#### d. Kaydetme Mekanizması (`ClipboardMonitor.swift`)

Uygulama, performansı optimize etmek için akıllı bir kaydetme stratejisi kullanır.

1.  **Gecikmeli Kaydetme (Debouncing):** Pano geçmişinde bir değişiklik olduğunda (yeni öğe ekleme, silme, favoriye ekleme vb.), veriler diske **hemen yazılmaz**. Bunun yerine `scheduleSave()` fonksiyonu tetiklenir.
2.  Bu fonksiyon, 0.5 saniyelik bir zamanlayıcı başlatır. Eğer bu süre içinde başka bir değişiklik olursa, önceki zamanlayıcı iptal edilir ve yenisi başlatılır.
3.  Bu sayede, art arda yapılan çok sayıda değişiklik (örneğin hızlıca 5 öğeyi silmek) tek bir disk yazma işleminde birleştirilir.
4.  **Context Kaydetme:** Süre dolduğunda, `saveContext()` fonksiyonu çağrılır ve `viewContext` üzerindeki tüm değişiklikler veritabanına kaydedilir. Bu işlem, `viewContext.hasChanges` kontrolü sayesinde sadece değişiklik varsa yapılır.
5.  **Uygulama Kapanırken Kaydetme:** Uygulama kapatılırken (`applicationWillTerminate`), o ana kadar kaydedilmemiş tüm bekleyen değişikliklerin kaybolmaması için `saveContext()` fonksiyonu son bir kez çağrılır.

#### e. Yükleme ve Görüntüleme Mekanizması (`ContentView.swift`)

Uygulama artık tüm verileri başlangıçta belleğe yüklemez. Bunun yerine, SwiftUI'ın güçlü `@FetchRequest` özelliğini kullanır:

- **Lazy Loading:** `ContentView`, `@FetchRequest` kullanarak verileri doğrudan Core Data'dan çeker. Bu, sadece ekranda o an görünen öğelerin veritabanından okunmasını sağlar (tembel yükleme).
- **Otomatik Güncelleme:** Veritabanında bir değişiklik olduğunda (yeni öğe, silme, güncelleme), `@FetchRequest` bu değişikliği otomatik olarak algılar ve arayüzü anında günceller. Bu, `updateFilteredItems` gibi manuel güncelleme fonksiyonlarına olan ihtiyacı ortadan kaldırır.
- **Verimli Filtreleme:** Arama ve sekme filtreleme işlemleri, `NSPredicate` kullanılarak doğrudan veritabanı seviyesinde yapılır. Bu, binlerce öğe arasında bile çok hızlı arama yapılmasını sağlar.
- **Akıllı Sıralama:** `@FetchRequest`'in sıralama tanımlayıcıları (`sortDescriptors`), önce sabitlenmiş (`isPinned`) öğeleri, ardından diğer tüm öğeleri tarihe göre sıralayacak şekilde ayarlanmıştır. Bu, sabitlenmiş öğelerin her zaman en üstte kalmasını garanti eder.

---

### 2. Veri Modeli Evrimi (Geçişler - Migrations)

Uygulama, gelecekteki veri modeli değişikliklerine (örneğin, `ClipboardItemEntity`'ye yeni bir özellik eklenmesi) karşı dayanıklıdır. `PersistenceController` içinde **hafif geçiş (lightweight migration)** otomatik olarak etkinleştirilmiştir. Bu sayede, veri modelinde basit değişiklikler yapıldığında, Core Data mevcut kullanıcı verilerini koruyarak veritabanı şemasını otomatik olarak günceller. Bu, kullanıcılar için sorunsuz ve veri kaybı olmayan bir güncelleme deneyimi sağlar.

---

### 3. Pano İzleme ve Kopyalama (`ClipboardMonitor.swift`)

Clippy, panodaki değişiklikleri sürekli olarak dinleyerek çalışır.

1.  **Zamanlayıcı (Timer):** `startMonitoring()` fonksiyonu, her 0.5 saniyede bir `checkClipboard()` fonksiyonunu çalıştıran bir zamanlayıcı başlatır.
2.  **Değişiklik Tespiti:** `checkClipboard()` fonksiyonu, panonun `changeCount` adı verilen bir sayacını kontrol eder. Eğer bu sayaç, bir önceki kontrolden farklıysa, panonun içeriğinin değiştiği anlaşılır.
3.  **İçerik Analizi:**
    - Önce panoda metin olup olmadığı kontrol edilir. Metin varsa, bu metinle yeni bir `ClipboardItem` oluşturulur.
    - Eğer metin yoksa, resim olup olmadığı kontrol edilir. Resim varsa, bu resim `saveImageInBackground` fonksiyonu ile arka planda `Images` klasörüne kaydedilir ve dosya yolunu içeren yeni bir `ClipboardItem` oluşturulur.
4.  **Kendi Kendini Tetiklemeyi Önleme:** Clippy bir yapıştırma işlemi yaptığında, panonun içeriğini kendisi değiştirir. Bu değişikliğin yeni bir kopyalama olarak algılanmasını önlemek için, yapıştırma sırasında panoya `com.yarasa.Clippy.paste` adında özel bir tür (type) eklenir. `checkClipboard()` fonksiyonu, panoda bu özel türü görürse, değişikliği görmezden gelir.

---

### 4. Yapıştırma Özellikleri

#### a. Standart Yapıştırma (`PasteManager.swift`)

1.  Kullanıcı "Yapıştır" butonuna bastığında `PasteManager` devreye girer.
2.  Uygulama penceresi hemen gizlenir (`closePopover`) ve odak, en son aktif olan uygulamaya geri döner.
3.  Küçük bir gecikmenin (0.2 saniye) ardından, yapıştırılacak öğe (metin veya resim) `NSPasteboard.general` üzerine yazılır.
4.  Son olarak, `Cmd (⌘) + V` klavye kısayolu programatik olarak simüle edilir. Bu, metnin hedef uygulamaya en güvenilir şekilde yapıştırılmasını sağlar.

#### b. Sıralı Yapıştırma (Sequential Paste)

Bu özellik, iki ana adımdan oluşur: "Sıraya Ekle" ve "Sıradakini Yapıştır".

1.  **Sıraya Ekle (`Cmd+Shift+C`):**

    - Kullanıcı bu kısayola bastığında, `AppDelegate` içindeki `updateSequentialCopyHotkey` fonksiyonu tetiklenir.
    - Bu fonksiyon, önce `ClipboardMonitor`'a bir sonraki kopyalama işleminin özel olduğunu bildiren bir işaret (`shouldAddToSequentialQueue = true`) koyar (`prepareForSequentialCopy`).
    - Hemen ardından, standart `Cmd (⌘) + C` (Kopyala) komutunu programatik olarak sisteme gönderir.
    - Sistem bu kopyalama işlemini gerçekleştirir ve panoyu günceller.
    - `ClipboardMonitor`'un `checkClipboard` fonksiyonu bu değişikliği algılar. `shouldAddToSequentialQueue` işareti `true` olduğu için, yeni kopyalanan öğenin ID'sini hem normal geçmişe ekler hem de `sequentialPasteQueueIDs` adlı özel bir diziye ekler. Son olarak işareti tekrar `false` yapar.

2.  **Sıradakini Yapıştır (`Cmd+Shift+B`):**
    - Kullanıcı bu kısayola bastığında, `pasteNextInSequence` fonksiyonu çalışır.
    - Bu fonksiyon, `sequentialPasteQueueIDs` dizisinden sıradaki öğenin ID'sini alır (`sequentialPasteIndex` sayacını kullanarak).
    - İlgili `ClipboardItem`'ı bulur ve `PasteManager` aracılığıyla standart yapıştırma işlemini gerçekleştirir.
    - Son olarak, `sequentialPasteIndex` sayacını bir artırarak bir sonraki basış için bir sonraki öğeyi hazırlar.

Bu yapı, özelliklerin hem performanslı hem de güvenilir bir şekilde çalışmasını sağlar.
