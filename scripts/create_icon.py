#!/usr/bin/env python3
"""
Создаёт иконку для SQL over CSV.
"""
import os
import subprocess
import tempfile
from pathlib import Path

def create_icon():
    script_dir = Path(__file__).parent.parent
    resources_dir = script_dir / "Resources"
    resources_dir.mkdir(exist_ok=True)
    icns_path = resources_dir / "AppIcon.icns"
    
    with tempfile.TemporaryDirectory() as tmpdir:
        iconset_dir = Path(tmpdir) / "AppIcon.iconset"
        iconset_dir.mkdir()
        
        # Размеры иконок для macOS
        sizes = [
            (16, "icon_16x16.png"),
            (32, "icon_16x16@2x.png"),
            (32, "icon_32x32.png"),
            (64, "icon_32x32@2x.png"),
            (128, "icon_128x128.png"),
            (256, "icon_128x128@2x.png"),
            (256, "icon_256x256.png"),
            (512, "icon_256x256@2x.png"),
            (512, "icon_512x512.png"),
            (1024, "icon_512x512@2x.png"),
        ]
        
        # Пробуем создать иконку с PIL
        try:
            from PIL import Image, ImageDraw, ImageFont
            
            for size, filename in sizes:
                img = create_icon_image(size)
                img.save(iconset_dir / filename, "PNG")
            
            # Конвертируем в icns
            subprocess.run([
                "iconutil", "-c", "icns", str(iconset_dir), "-o", str(icns_path)
            ], check=True)
            
            print(f"✓ Иконка создана: {icns_path}")
            return True
            
        except ImportError:
            print("PIL не установлен, создаю простую иконку...")
            return create_simple_icon(iconset_dir, icns_path, sizes)


def create_icon_image(size):
    """Создаёт PNG иконку указанного размера с PIL."""
    from PIL import Image, ImageDraw, ImageFont
    
    # Создаём изображение с прозрачным фоном
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Пропорции
    margin = int(size * 0.04)
    corner_radius = int(size * 0.18)
    
    # Фон (фиолетовый градиент - упрощаем до сплошного цвета)
    bg_color = (99, 102, 241)  # #6366f1
    
    # Рисуем скруглённый прямоугольник
    draw.rounded_rectangle(
        [margin, margin, size - margin, size - margin],
        radius=corner_radius,
        fill=bg_color
    )
    
    # Рисуем таблицу (белые полоски слева)
    table_x = int(size * 0.12)
    table_y = int(size * 0.28)
    table_w = int(size * 0.28)
    row_h = int(size * 0.06)
    row_gap = int(size * 0.01)
    
    for i in range(5):
        opacity = int(255 * (0.95 - i * 0.1))
        y = table_y + i * (row_h + row_gap)
        draw.rounded_rectangle(
            [table_x, y, table_x + table_w, y + row_h],
            radius=int(size * 0.008),
            fill=(255, 255, 255, opacity)
        )
    
    # Стрелка (зелёная)
    arrow_color = (34, 197, 94)  # #22c55e
    arrow_x = int(size * 0.43)
    arrow_y = int(size * 0.42)
    arrow_w = int(size * 0.16)
    arrow_h = int(size * 0.16)
    
    # Рисуем стрелку как полигон
    points = [
        (arrow_x, arrow_y + arrow_h * 0.3),
        (arrow_x + arrow_w * 0.6, arrow_y + arrow_h * 0.3),
        (arrow_x + arrow_w * 0.6, arrow_y),
        (arrow_x + arrow_w, arrow_y + arrow_h * 0.5),
        (arrow_x + arrow_w * 0.6, arrow_y + arrow_h),
        (arrow_x + arrow_w * 0.6, arrow_y + arrow_h * 0.7),
        (arrow_x, arrow_y + arrow_h * 0.7),
    ]
    draw.polygon(points, fill=arrow_color)
    
    # Текст SQL (справа)
    try:
        font_size = int(size * 0.18)
        font = ImageFont.truetype("/System/Library/Fonts/SFNSMono.ttf", font_size)
    except:
        try:
            font = ImageFont.truetype("/System/Library/Fonts/Monaco.ttf", font_size)
        except:
            font = ImageFont.load_default()
    
    sql_x = int(size * 0.62)
    sql_y = int(size * 0.35)
    draw.text((sql_x, sql_y), "SQL", fill=(255, 255, 255), font=font)
    
    # Текст CSV (внизу)
    try:
        font_size_csv = int(size * 0.1)
        font_csv = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", font_size_csv)
    except:
        font_csv = font
    
    csv_bbox = draw.textbbox((0, 0), "CSV", font=font_csv)
    csv_w = csv_bbox[2] - csv_bbox[0]
    csv_x = (size - csv_w) // 2
    csv_y = int(size * 0.75)
    draw.text((csv_x, csv_y), "CSV", fill=(255, 255, 255, 230), font=font_csv)
    
    return img


def create_simple_icon(iconset_dir, icns_path, sizes):
    """Создаёт простую иконку без PIL."""
    # Используем системную иконку как базу
    system_icon = "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/SidebarDocumentsFolder.icns"
    
    if not os.path.exists(system_icon):
        system_icon = "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericDocumentIcon.icns"
    
    for size, filename in sizes:
        png_path = iconset_dir / filename
        subprocess.run([
            "sips", "-s", "format", "png", "-z", str(size), str(size),
            system_icon, "--out", str(png_path)
        ], capture_output=True)
    
    result = subprocess.run([
        "iconutil", "-c", "icns", str(iconset_dir), "-o", str(icns_path)
    ], capture_output=True)
    
    if result.returncode == 0:
        print(f"✓ Создана простая иконка: {icns_path}")
        return True
    else:
        print(f"✗ Не удалось создать иконку")
        return False


if __name__ == "__main__":
    create_icon()
