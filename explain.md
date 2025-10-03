# Clippy Teknik Mimarisi ve Derinlemesine Bakış

Bu doküman, Clippy uygulamasının temel özelliklerinin ve mekanizmalarının arka planda nasıl çalıştığını, hangi teknoloji ve algoritmaları kullandığını detaylı bir şekilde açıklamaktadır.

## 1. Temel Altyapı ve Veri Yönetimi

### 1.1. Veri Saklama: Core Data ile Performans ve Güvenilirlik

Uygulama, tüm pano geçmişini, favorileri ve ayarları yönetmek için Apple'ın modern ve güçlü **Core Data** çerçevesini kullanır.

- **Veritabanı:** Tüm meta veriler (metin, tarih, favori durumu vb.) tek bir SQLite veritabanında saklanır.
  - **Konum:** `~/Library/Application Support/Clippy/Clippy.sqlite`
- **Resim Dosyaları:** Kopyalanan resimler, veritabanını şişirmemek ve performansı yüksek tutmak için ayrı dosyalar olarak saklanır. Veritabanında sadece bu resimlerin dosya adları tutulur.
  - **Konum:** `~/Library/Application Support/Clippy/Images/`

#### Veri Modeli (`ClipboardItemEntity`)

Core Data modelimiz, kopyalanan her bir öğeyi temsil eden `ClipboardItemEntity` adında tek bir varlıktan (entity) oluşur. Bu varlık, bir öğenin tüm niteliklerini içerir: `id`, `date`, `content`, `contentType`, `isFavorite`, `isPinned`, `isCode`, `sourceAppName`, `keyword` vb.

#### Mimari (`PersistenceController.swift`)

- **Singleton Yapısı:** `PersistenceController.shared`, uygulama genelinde Core Data yığınına tek bir noktadan erişim sağlar.
- **Ana Context (`viewContext`):** Tüm SwiftUI görünümleri ve ana iş parçacığında çalışan servisler, veri okuma/yazma işlemleri için bu `NSManagedObjectContext`'i kullanır.
- **Otomatik Birleştirme:** `automaticallyMergesChangesFromParent` özelliği sayesinde, arka planda yapılan değişiklikler (örneğin, pano izleyiciden gelen yeni bir öğe) ana `viewContext`'e ve dolayısıyla kullanıcı arayüzüne otomatik olarak yansıtılır.

#### Akıllı Kaydetme (Debouncing)

Performansı optimize etmek için, her değişiklik (ekleme, silme, favoriye ekleme) diske anında yazılmaz.

1. Bir değişiklik olduğunda, `scheduleSave()` metodu 0.5 saniyelik bir zamanlayıcı başlatır.
2. Bu süre içinde yeni bir değişiklik olursa, önceki zamanlayıcı iptal edilir ve yenisi başlar.
3. Bu "debouncing" tekniği sayesinde, art arda yapılan çok sayıda işlem (örneğin 5 öğeyi hızla silmek) tek bir veritabanı yazma operasyonunda birleştirilir. Bu, disk I/O'sunu ve işlemci yükünü önemli ölçüde azaltır.
4. Uygulama kapatılırken (`applicationWillTerminate`), kaydedilmemiş tüm değişikliklerin kaybolmaması için `saveContext()` son bir kez çağrılır.

### 1.2. Veri Görüntüleme: SwiftUI ve `@FetchRequest`

Uygulama, verileri verimli bir şekilde görüntülemek için SwiftUI'ın gücünden sonuna kadar faydalanır.

- **Tembel Yükleme (Lazy Loading):** `ContentView`, verileri doğrudan Core Data'dan çekmek için `@FetchRequest` kullanır. Bu, binlerce öğeniz olsa bile, sadece ekranda o an görünen öğelerin veritabanından okunmasını sağlar. Tüm veritabanını belleğe yükleme gibi verimsiz bir yöntemden kaçınılır.
- **Dinamik Filtreleme ve Sıralama:**
  - Arama çubuğuna yazılan metin veya sekmeler arası geçiş, `@FetchRequest`'in `nsPredicate` özelliğini dinamik olarak günceller. Bu filtreleme, doğrudan veritabanı seviyesinde (SQLite sorgusu olarak) çalışır ve bu nedenle son derece hızlıdır.
  - Sıralama, `NSSortDescriptor` ile yapılır. Önce sabitlenmiş (`isPinned`) öğeler, ardından diğer tüm öğeler tarihe göre sıralanır. Bu, sabitlenmiş öğelerin her zaman en üstte kalmasını garanti eder.
- **Otomatik Arayüz Güncelleme:** Core Data veritabanında herhangi bir değişiklik olduğunda (yeni öğe, favori durumu değişikliği vb.), `@FetchRequest` bu değişikliği otomatik olarak algılar ve SwiftUI listesini anında yeniden çizer. Bu, manuel veri yenileme ve durum yönetimi karmaşasını ortadan kaldırır.

## 2. Pano İzleme ve Akıllı Algılama (`ClipboardMonitor.swift`)

- **Mekanizma:** Her 0.5 saniyede bir çalışan bir `Timer`, panonun `changeCount` adı verilen dahili sayacını kontrol eder. Eğer bu sayaç bir önceki kontrolden farklıysa, panonun içeriğinin değiştiği anlaşılır.
- **İçerik Analizi:** Yeni içerik algılandığında, önce metin olup olmadığı, ardından resim olup olmadığı kontrol edilir.
- **Akıllı Tespit:** Kopyalanan metin, `NSDataDetector` gibi sistem API'leri kullanılarak analiz edilir. "Yarın 14:00'te toplantı" gibi bir ifade algılanırsa, bu tarih ayrıştırılır ve öğenin `detectedDate` özelliğine kaydedilir. Bu, arayüzde "Takvime Ekle" gibi bağlamsal butonların gösterilmesini sağlar.
- **Kod Algılama:** Metin içeriği, kodda sıkça rastlanan desenlere (parantezler, noktalı virgüller, anahtar kelimeler) göre analiz edilir ve `isCode` olarak işaretlenir.
- **Döngü Önleme:** Clippy'nin kendisi bir yapıştırma işlemi yaptığında, panonun içeriğini değiştirir. Bu değişikliğin yeni bir kopyalama olarak algılanmasını önlemek için, yapıştırma sırasında panoya `com.yarasa.Clippy.paste` adında özel bir veri türü eklenir. Pano izleyici bu türü gördüğünde, o değişikliği görmezden gelir.

## 3. Gelişmiş Özelliklerin Çalışma Mantığı

### 3.1. Sıralı Yapıştırma (Sequential Paste)

Bu özellik, kopyalama ve yapıştırma kısayollarını zekice yöneterek çalışır.

1. **Sıraya Ekle (`Cmd+Shift+C`):**
   - Bu kısayola basıldığında, Clippy önce `ClipboardMonitor`'da `shouldAddToSequentialQueue` adında bir bayrağı `true` yapar.
   - Hemen ardından, programatik olarak standart `Cmd+C` (Kopyala) tuş kombinasyonunu sisteme gönderir.
   - Sistem kopyalama işlemini yapar ve panoyu günceller.
   - `ClipboardMonitor`, pano değişikliğini algıladığında `shouldAddToSequentialQueue` bayrağının `true` olduğunu görür. Yeni kopyalanan öğenin ID'sini hem normal geçmişe ekler hem de `sequentialPasteQueueIDs` adlı özel bir sıraya (diziye) ekler. Son olarak bayrağı tekrar `false` yapar.
2. **Sıradakini Yapıştır (`Cmd+Shift+B`):**
   - Bu kısayola basıldığında, `pasteNextInSequence` fonksiyonu çalışır.
   - Bu fonksiyon, `sequentialPasteQueueIDs` dizisinden sıradaki öğenin ID'sini alır, ilgili öğeyi veritabanından bulur ve `PasteManager` aracılığıyla yapıştırır. Bir sayaç, sırada hangi öğenin olduğunu takip eder.

### 3.2. Fark Görüntüleyici (Diff View)

- **Algoritma:** İki metin arasındaki farkları göstermek için basit bir satır karşılaştırması yerine, daha gelişmiş bir **Longest Common Subsequence (LCS)** algoritması kullanılır. Bu, eklenen, silinen veya yeri değişen satırları doğru bir şekilde hizalar ve anlamsız boşlukları ortadan kaldırır.
- **Karakter Vurgulama:** Değiştirilmiş olarak tespit edilen satırlar için, Swift'in `difference(from:)` metodu kullanılarak karakter bazında bir karşılaştırma daha yapılır. Sonuç, `AttributedString` kullanılarak, eklenen ve silinen karakterleri farklı arka plan renkleriyle vurgulayan bir metin olarak oluşturulur.

### 3.3. Anahtar Kelime ile Yapıştırma (Keyword Expansion)

Bu özellik, performansı en üst düzeyde tutmak için tasarlanmış akıllı bir mimariye sahiptir.

1. **Global Olay Dinleyici:** `NSEvent.addGlobalMonitorForEvents` API'si kullanılarak, sistem genelindeki tüm klavye girişleri dinlenir.
2. **Akıllı Tetikleme ve Arabellek (Buffer):**
   - Özellik, sadece tetikleyici karakter (`;`) yazıldığında aktif hale gelir ve yazılan karakterleri geçici bir arabellekte (`currentBuffer`) biriktirmeye başlar.
   - Kullanıcı yazmaya devam ettikçe arabellek güncellenir. Eğer 2 saniye boyunca yeni bir tuşa basılmazsa veya "boşluk", "enter" gibi bir sonlandırıcı karakter yazılırsa, arabellek sıfırlanır. Bu, gereksiz yere her tuş vuruşunu kontrol etmeyi önler.
3. **Önbellekleme (Caching):**
   - Uygulama, anahtar kelimesi olan tüm öğeleri başlangıçta ve her değişiklik olduğunda veritabanından okuyup bir sözlük (`[String: String]`) içinde belleğe yükler (`keywordCache`).
   - Kullanıcı bir anahtar kelime yazdığında, Clippy veritabanına sorgu göndermek yerine, **doğrudan bu süper hızlı bellek içi sözlükte** arama yapar. Bu, anlık bir yanıt süresi sağlar ve sistem kaynaklarını tüketmez.
4. **Değiştirme İşlemi:**
   - Eşleşen bir anahtar kelime bulunduğunda, `PasteManager` önce yazdığınız anahtar kelimeyi (örn: `;imza`) silmek için programatik olarak "geri sil" (backspace) komutları gönderir.
   - Silme işlemi bittikten hemen sonra, asıl içeriği yapıştırır.

### 3.4. Resim Düzenleyici

- **Mimari:** Resim düzenleyici, SwiftUI ve AppKit'in birleşiminden oluşur. Ana arayüz SwiftUI ile oluşturulurken, asıl çizim tuvali, hassas mouse olaylarını yönetmek için özelleştirilmiş bir `NSView` alt sınıfı olan `DrawingNSView`'dir.
- **Çizim Mantığı:**
  - Kullanıcı mouse'a bastığında (`mouseDown`), başlangıç noktası kaydedilir.
  - Mouse'u sürüklediğinde (`mouseDragged`), başlangıç ve mevcut nokta arasında seçili araca (ok, dörtgen) göre geçici bir şekil (`currentShape`) oluşturulur ve `needsDisplay = true` çağrılarak tuval sürekli güncellenir.
  - Mouse bırakıldığında (`mouseUp`), bu geçici şekil, kalıcı şekillerin tutulduğu `shapes` dizisine eklenir.
- **Metin Ekleme:** Metin aracı seçiliyken, kullanıcı bir alan çizdiğinde, o alana bir `NSTextView` yerleştirilir ve klavye odağı ona verilir. Kullanıcı yazmayı bitirip başka bir yere tıkladığında (`didEndEditingNotification`), `NSTextView`'daki metin ve konumu, kalıcı bir metin şekline dönüştürülerek `shapes` dizisine eklenir ve `NSTextView` kaldırılır.

### 3.5. Uyku Modu Desteği

macOS, uyku moduna geçtiğinde bazı sistem servislerini ve zamanlayıcıları duraklatabilir. Clippy'nin uyandıktan sonra sorunsuz çalışmaya devam etmesi için:

- `AppDelegate`, `NSWorkspace.didWakeNotification` adlı sistem bildirimini dinler.
- Bilgisayar uyandığında bu bildirim tetiklenir ve `systemDidWake` metodu çağrılır.
- Bu metod, `ClipboardMonitor`'ı, `KeywordExpansionManager`'ı ve tüm global klavye kısayollarını (`HotKey`) durdurup yeniden başlatır. Bu, uygulamanın tüm işlevselliğinin taze ve çalışır durumda olmasını garanti eder.
