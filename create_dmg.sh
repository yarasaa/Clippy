#!/bin/bash

# Bu betik, Clippy uygulaması için bir .dmg dosyası oluşturur.
# Kullanım: Terminalde projenin ana dizinindeyken `./create_dmg.sh` komutunu çalıştırın.
# İlk çalıştırmadan önce `chmod +x create_dmg.sh` komutuyla betiği çalıştırılabilir yapmanız gerekebilir.

# --- Değişkenler ---
APP_NAME="Clippy"
PROJECT_NAME="Clippy"
SCHEME_NAME="Clippy"

# Versiyon numarasını al. Önce agvtool'u dene, başarısız olursa GITHUB_REF_NAME'den al.
VERSION=$(agvtool what-marketing-version -terse1 2>/dev/null)
if [ -z "$VERSION" ]; then
    echo "⚠️ agvtool ile versiyon alınamadı. Etiket (tag) adı kullanılacak."
    # GITHUB_REF_NAME, GitHub Actions'da 'v1.2.3' gibi bir değer içerir.
    # Başındaki 'v' harfini kaldırıyoruz.
    VERSION=${GITHUB_REF_NAME#v}
fi

BUILD_NUMBER=$(agvtool what-version -terse 2>/dev/null || echo "1")

FINAL_DMG_NAME="${APP_NAME}_${VERSION}_${BUILD_NUMBER}.dmg"
VOLUME_NAME="${APP_NAME} ${VERSION}"

BUILD_DIR="build"
ARCHIVE_PATH="${BUILD_DIR}/${PROJECT_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"
APP_PATH="${EXPORT_PATH}/${APP_NAME}.app"

DMG_TEMP_NAME="${BUILD_DIR}/temp.dmg"

# DMG penceresi için arka plan resmi (isteğe bağlı)
# Bu dosyayı projenizin içinde bir yerde oluşturmanız gerekir. Örn: "dmg_assets/background.png"
DMG_BACKGROUND_IMAGE="dmg_assets/background.png"

# --- Betik Başlangıcı ---

echo "🚀 DMG oluşturma işlemi başlıyor: ${FINAL_DMG_NAME}"

# 1. Önceki build dosyalarını temizle
echo "🧹 Önceki build dosyaları temizleniyor..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# 2. Uygulamayı arşivle
echo "📦 Uygulama arşivleniyor..."
xcodebuild -project "${PROJECT_NAME}.xcodeproj" \
           -scheme "${SCHEME_NAME}" \
           -configuration Release \
           -archivePath "${ARCHIVE_PATH}" \
           clean archive \
           CODE_SIGN_IDENTITY="" \
           CODE_SIGNING_REQUIRED=NO

if [ $? -ne 0 ]; then
    echo "❌ Arşivleme başarısız oldu."
    exit 1
fi

# 3. Arşivden uygulamayı dışa aktar
echo "📤 Uygulama arşivden dışa aktarılıyor..."
xcodebuild -exportArchive \
           -archivePath "${ARCHIVE_PATH}" \
           -exportPath "${EXPORT_PATH}" \
           -exportOptionsPlist "ExportOptions.plist"

if [ $? -ne 0 ]; then
    echo "❌ Dışa aktarma başarısız oldu. ExportOptions.plist dosyasını kontrol edin."
    exit 1
fi

# 4. Geçici bir disk imajı oluştur
echo "💿 Geçici disk imajı oluşturuluyor..."
hdiutil create -o "${DMG_TEMP_NAME}" -size 200m -volname "${VOLUME_NAME}" -fs HFS+ -format UDRW

# 5. Disk imajını bağla
echo "🔗 Disk imajı bağlanıyor..."
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "${DMG_TEMP_NAME}" | egrep '^/dev/' | sed 1q | awk '{print $1}')

# 6. Dosyaları kopyala ve özelleştir
echo "🎨 Görünüm özelleştiriliyor ve dosyalar kopyalanıyor..."
sleep 2 # Diskin tam olarak bağlanması için kısa bir bekleme

VOLUME_PATH="/Volumes/${VOLUME_NAME}"

# Uygulamayı kopyala
cp -R "${APP_PATH}" "${VOLUME_PATH}"

# Çözüm: Uygulamanın ikonunu alıp DMG'nin ikonu olarak ayarla.
# .icns dosyasını DMG'nin içine kopyala, görünmez yap ve volume ikonu olarak ata.
cp "${APP_PATH}/Contents/Resources/AppIcon.icns" "${VOLUME_PATH}/.VolumeIcon.icns"
SetFile -a C "${VOLUME_PATH}"
SetFile -a V "${VOLUME_PATH}/.VolumeIcon.icns"


# /Applications klasörüne sembolik link oluştur
ln -s /Applications "${VOLUME_PATH}/Applications"

# Arka plan resmini ve ikon pozisyonlarını ayarla (AppleScript ile)
if [ -f "$DMG_BACKGROUND_IMAGE" ]; then
  mkdir "${VOLUME_PATH}/.background"
  cp "$DMG_BACKGROUND_IMAGE" "${VOLUME_PATH}/.background/"
  
  osascript <<EOD
tell application "Finder"
  tell disk "'${VOLUME_NAME}'"
    open
    set current view of container window to icon view
    set the bounds of container window to {400, 100, 950, 480}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 100
    set background picture of viewOptions to file ".background:'${DMG_BACKGROUND_IMAGE##*/}'"
    set position of item "'${APP_NAME}.app'" of container window to {150, 190}
    set position of item "Applications" of container window to {400, 190}
    update without registering applications
    delay 1
    close
  end tell
end tell
EOD
fi

# 7. Disk imajını ayır
echo "🔌 Disk imajı ayrılıyor..."
hdiutil detach "${DEVICE}"

# 8. Son DMG dosyasını oluştur
echo "📦 Son sıkıştırılmış DMG dosyası oluşturuluyor..."
hdiutil convert "${DMG_TEMP_NAME}" -format UDZO -imagekey zlib-level=9 -o "${BUILD_DIR}/${FINAL_DMG_NAME}"

# 9. Geçici dosyaları temizle
echo "🧹 Geçici dosyalar siliniyor..."
rm "${DMG_TEMP_NAME}"

echo "✅ Başarılı! DMG dosyası oluşturuldu: ${BUILD_DIR}/${FINAL_DMG_NAME}"

open "${BUILD_DIR}"