# SQL over CSV - Makefile
# Сборка и установка приложения

APP_NAME = SQL over CSV
BINARY_NAME = SQLoverCSV
BUNDLE_ID = com.sqlovercsv.app
INSTALL_DIR = /Applications

.PHONY: build install uninstall clean icon run

# Сборка релизной версии
build: icon
	@echo "==> Собираю релиз..."
	swift build -c release
	@$(MAKE) bundle

# Создание .app бандла
bundle:
	@echo "==> Создаю бандл..."
	@BIN_PATH=$$(swift build -c release --show-bin-path) && \
	APP_DIR="$$BIN_PATH/$(APP_NAME).app" && \
	rm -rf "$$APP_DIR" && \
	mkdir -p "$$APP_DIR/Contents/MacOS" && \
	mkdir -p "$$APP_DIR/Contents/Resources" && \
	cp "$$BIN_PATH/$(BINARY_NAME)" "$$APP_DIR/Contents/MacOS/$(BINARY_NAME)" && \
	cp -r scripts "$$APP_DIR/Contents/Resources/" 2>/dev/null || true && \
	if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns "$$APP_DIR/Contents/Resources/"; fi && \
	echo '<?xml version="1.0" encoding="UTF-8"?>' > "$$APP_DIR/Contents/Info.plist" && \
	echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> "$$APP_DIR/Contents/Info.plist" && \
	echo '<plist version="1.0"><dict>' >> "$$APP_DIR/Contents/Info.plist" && \
	echo '<key>CFBundleName</key><string>$(APP_NAME)</string>' >> "$$APP_DIR/Contents/Info.plist" && \
	echo '<key>CFBundleDisplayName</key><string>$(APP_NAME)</string>' >> "$$APP_DIR/Contents/Info.plist" && \
	echo '<key>CFBundleExecutable</key><string>$(BINARY_NAME)</string>' >> "$$APP_DIR/Contents/Info.plist" && \
	echo '<key>CFBundleIdentifier</key><string>$(BUNDLE_ID)</string>' >> "$$APP_DIR/Contents/Info.plist" && \
	echo '<key>CFBundleVersion</key><string>1.0</string>' >> "$$APP_DIR/Contents/Info.plist" && \
	echo '<key>CFBundleShortVersionString</key><string>1.0</string>' >> "$$APP_DIR/Contents/Info.plist" && \
	echo '<key>CFBundlePackageType</key><string>APPL</string>' >> "$$APP_DIR/Contents/Info.plist" && \
	echo '<key>CFBundleIconFile</key><string>AppIcon</string>' >> "$$APP_DIR/Contents/Info.plist" && \
	echo '<key>LSMinimumSystemVersion</key><string>13.0</string>' >> "$$APP_DIR/Contents/Info.plist" && \
	echo '<key>NSHighResolutionCapable</key><true/>' >> "$$APP_DIR/Contents/Info.plist" && \
	echo '<key>NSPrincipalClass</key><string>NSApplication</string>' >> "$$APP_DIR/Contents/Info.plist" && \
	echo '<key>CFBundleDocumentTypes</key><array><dict>' >> "$$APP_DIR/Contents/Info.plist" && \
	echo '<key>CFBundleTypeName</key><string>CSV File</string>' >> "$$APP_DIR/Contents/Info.plist" && \
	echo '<key>CFBundleTypeRole</key><string>Viewer</string>' >> "$$APP_DIR/Contents/Info.plist" && \
	echo '<key>LSItemContentTypes</key><array><string>public.comma-separated-values-text</string><string>public.plain-text</string></array>' >> "$$APP_DIR/Contents/Info.plist" && \
	echo '</dict></array></dict></plist>' >> "$$APP_DIR/Contents/Info.plist" && \
	echo "==> Готово: $$APP_DIR"

# Создание иконки
icon:
	@echo "==> Создаю иконку..."
	@mkdir -p Resources
	@python3 scripts/create_icon.py || echo "Иконка не создана (необязательно)"

# Установка в /Applications
install: build
	@echo "==> Устанавливаю в $(INSTALL_DIR)..."
	@BIN_PATH=$$(swift build -c release --show-bin-path) && \
	APP_DIR="$$BIN_PATH/$(APP_NAME).app" && \
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app" && \
	cp -R "$$APP_DIR" "$(INSTALL_DIR)/" && \
	echo "==> Установлено: $(INSTALL_DIR)/$(APP_NAME).app" && \
	echo "==> Открываю приложение..." && \
	open "$(INSTALL_DIR)/$(APP_NAME).app"

# Удаление из /Applications  
uninstall:
	@echo "==> Удаляю из $(INSTALL_DIR)..."
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "==> Готово"

# Очистка
clean:
	@echo "==> Очищаю..."
	swift package clean
	rm -rf .build
	rm -rf Resources/AppIcon.icns
	@echo "==> Готово"

# Запуск debug-версии
run:
	@echo "==> Запускаю debug-версию..."
	swift build
	.build/debug/$(BINARY_NAME)

# Справка
help:
	@echo "SQL over CSV - Makefile"
	@echo ""
	@echo "Команды:"
	@echo "  make build    - Собрать релизную версию"
	@echo "  make install  - Собрать и установить в /Applications"
	@echo "  make uninstall - Удалить из /Applications"
	@echo "  make run      - Запустить debug-версию"
	@echo "  make clean    - Очистить сборку"
	@echo "  make help     - Эта справка"
