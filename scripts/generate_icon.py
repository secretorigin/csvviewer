#!/usr/bin/env python3
"""
Генерирует иконку приложения SQL over CSV.
Создаёт .icns файл для macOS.
"""
import subprocess
import tempfile
import os
from pathlib import Path

def create_icon_svg():
    """Создаёт SVG иконку."""
    return '''<?xml version="1.0" encoding="UTF-8"?>
<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#6366f1"/>
      <stop offset="100%" style="stop-color:#4f46e5"/>
    </linearGradient>
    <linearGradient id="accent" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#22c55e"/>
      <stop offset="100%" style="stop-color:#16a34a"/>
    </linearGradient>
  </defs>
  
  <!-- Фон с закруглёнными углами -->
  <rect x="40" y="40" width="944" height="944" rx="180" fill="url(#bg)"/>
  
  <!-- CSV таблица (слева) -->
  <g transform="translate(120, 280)">
    <!-- Ячейки таблицы -->
    <rect x="0" y="0" width="280" height="60" rx="8" fill="white" opacity="0.95"/>
    <rect x="0" y="70" width="280" height="60" rx="8" fill="white" opacity="0.85"/>
    <rect x="0" y="140" width="280" height="60" rx="8" fill="white" opacity="0.75"/>
    <rect x="0" y="210" width="280" height="60" rx="8" fill="white" opacity="0.65"/>
    <rect x="0" y="280" width="280" height="60" rx="8" fill="white" opacity="0.55"/>
    
    <!-- Разделители колонок -->
    <line x1="90" y1="0" x2="90" y2="340" stroke="#6366f1" stroke-width="3" opacity="0.5"/>
    <line x1="185" y1="0" x2="185" y2="340" stroke="#6366f1" stroke-width="3" opacity="0.5"/>
  </g>
  
  <!-- Стрелка -->
  <g transform="translate(440, 420)">
    <path d="M0,60 L100,60 L100,20 L160,80 L100,140 L100,100 L0,100 Z" fill="url(#accent)"/>
  </g>
  
  <!-- SQL символ (справа) -->
  <g transform="translate(620, 300)">
    <text x="0" y="180" font-family="SF Mono, Monaco, Menlo, monospace" font-size="200" font-weight="bold" fill="white">
      SQL
    </text>
  </g>
  
  <!-- CSV надпись внизу -->
  <text x="512" y="820" font-family="SF Pro Display, -apple-system, sans-serif" font-size="100" font-weight="600" fill="white" text-anchor="middle" opacity="0.9">
    CSV
  </text>
</svg>'''


def generate_icns(output_path):
    """Генерирует .icns файл из SVG."""
    with tempfile.TemporaryDirectory() as tmpdir:
        svg_path = os.path.join(tmpdir, "icon.svg")
        iconset_path = os.path.join(tmpdir, "AppIcon.iconset")
        
        # Сохраняем SVG
        with open(svg_path, 'w') as f:
            f.write(create_icon_svg())
        
        # Создаём iconset директорию
        os.makedirs(iconset_path)
        
        # Размеры для иконок macOS
        sizes = [16, 32, 64, 128, 256, 512, 1024]
        
        for size in sizes:
            # Обычная версия
            png_path = os.path.join(iconset_path, f"icon_{size}x{size}.png")
            subprocess.run([
                "sips", "-s", "format", "png",
                "--resampleHeightWidth", str(size), str(size),
                svg_path, "--out", png_path
            ], capture_output=True, check=False)
            
            # @2x версия (для Retina)
            if size <= 512:
                png_path_2x = os.path.join(iconset_path, f"icon_{size}x{size}@2x.png")
                subprocess.run([
                    "sips", "-s", "format", "png",
                    "--resampleHeightWidth", str(size * 2), str(size * 2),
                    svg_path, "--out", png_path_2x
                ], capture_output=True, check=False)
        
        # Пробуем через qlmanage если sips не сработал с SVG
        # Альтернативно создадим PNG напрямую
        png_1024 = os.path.join(tmpdir, "icon_1024.png")
        
        # Используем Python для создания PNG если есть PIL
        try:
            create_png_icon(png_1024)
            
            # Генерируем все размеры из PNG
            for size in sizes:
                png_path = os.path.join(iconset_path, f"icon_{size}x{size}.png")
                subprocess.run([
                    "sips", "-z", str(size), str(size),
                    png_1024, "--out", png_path
                ], capture_output=True, check=True)
                
                if size <= 512:
                    png_path_2x = os.path.join(iconset_path, f"icon_{size}x{size}@2x.png")
                    subprocess.run([
                        "sips", "-z", str(size * 2), str(size * 2),
                        png_1024, "--out", png_path_2x
                    ], capture_output=True, check=True)
            
            # Конвертируем iconset в icns
            subprocess.run([
                "iconutil", "-c", "icns", iconset_path, "-o", output_path
            ], check=True)
            
            print(f"Иконка создана: {output_path}")
            return True
            
        except Exception as e:
            print(f"Ошибка создания иконки: {e}")
            # Создаём простую иконку через sips
            return create_simple_icon(output_path)


def create_png_icon(output_path):
    """Создаёт PNG иконку с помощью Core Graphics через Python."""
    import ctypes
    from ctypes import c_void_p, c_double, c_uint32, c_size_t
    
    # Загружаем CoreGraphics
    cg = ctypes.CDLL('/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics')
    
    size = 1024
    
    # Создаём bitmap context
    cg.CGColorSpaceCreateDeviceRGB.restype = c_void_p
    colorspace = cg.CGColorSpaceCreateDeviceRGB()
    
    cg.CGBitmapContextCreate.restype = c_void_p
    cg.CGBitmapContextCreate.argtypes = [c_void_p, c_size_t, c_size_t, c_size_t, c_size_t, c_void_p, c_uint32]
    
    ctx = cg.CGBitmapContextCreate(
        None, size, size, 8, size * 4, colorspace,
        1 | (2 << 12)  # kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big
    )
    
    if not ctx:
        raise Exception("Не удалось создать контекст")
    
    # Рисуем фон (фиолетовый градиент)
    cg.CGContextSetRGBFillColor.argtypes = [c_void_p, c_double, c_double, c_double, c_double]
    cg.CGContextSetRGBFillColor(ctx, 0.388, 0.4, 0.945, 1.0)  # #6366f1
    
    cg.CGContextAddRoundedRect = None  # Нет такой функции, используем простой rect
    cg.CGContextFillRect.argtypes = [c_void_p, ctypes.c_double * 4]
    
    # Упрощаем - рисуем квадрат
    rect = (ctypes.c_double * 4)(40, 40, 944, 944)
    cg.CGContextFillRect(ctx, rect)
    
    # Создаём изображение
    cg.CGBitmapContextCreateImage.restype = c_void_p
    image = cg.CGBitmapContextCreateImage(ctx)
    
    # Сохраняем в PNG
    from Foundation import NSURL
    from Quartz import CGImageDestinationCreateWithURL, CGImageDestinationAddImage, CGImageDestinationFinalize
    
    url = NSURL.fileURLWithPath_(output_path)
    dest = CGImageDestinationCreateWithURL(url, "public.png", 1, None)
    CGImageDestinationAddImage(dest, image, None)
    CGImageDestinationFinalize(dest)


def create_simple_icon(output_path):
    """Создаёт простую иконку через системные средства."""
    with tempfile.TemporaryDirectory() as tmpdir:
        iconset_path = os.path.join(tmpdir, "AppIcon.iconset")
        os.makedirs(iconset_path)
        
        # Создаём простой PNG с помощью macOS screencapture трюка или sips
        # Используем готовый системный значок как базу
        
        sizes = [16, 32, 128, 256, 512]
        
        for size in sizes:
            png_path = os.path.join(iconset_path, f"icon_{size}x{size}.png")
            # Создаём пустое изображение нужного размера
            subprocess.run([
                "sips", "-g", "all",
                "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericDocumentIcon.icns",
            ], capture_output=True)
            
            # Копируем системную иконку документа как заглушку
            subprocess.run([
                "sips", "-s", "format", "png", "-z", str(size), str(size),
                "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericDocumentIcon.icns",
                "--out", png_path
            ], capture_output=True)
            
            if size <= 512:
                png_path_2x = os.path.join(iconset_path, f"icon_{size}x{size}@2x.png")
                subprocess.run([
                    "sips", "-s", "format", "png", "-z", str(size * 2), str(size * 2),
                    "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericDocumentIcon.icns",
                    "--out", png_path_2x
                ], capture_output=True)
        
        # Генерируем icns
        result = subprocess.run([
            "iconutil", "-c", "icns", iconset_path, "-o", output_path
        ], capture_output=True)
        
        return result.returncode == 0


if __name__ == "__main__":
    script_dir = Path(__file__).parent.parent
    icon_path = script_dir / "Resources" / "AppIcon.icns"
    icon_path.parent.mkdir(parents=True, exist_ok=True)
    generate_icns(str(icon_path))
