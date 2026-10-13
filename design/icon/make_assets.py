"""앱 아이콘 A-4와 실행 화면 그림(LaunchMark)을 만든다.

디자인: 춘배 캔버스 "아이콘 확정안과 에셋 목록" (사용자 확정, 2026-10-09).
SVG를 만든 뒤 Chrome headless로 PNG를 찍고, Pillow로 크기·알파를 맞춘다.

    python design/icon/make_assets.py

결과
- design/icon/svg/*.svg                  원본 SVG (iOS 26 Icon Composer 레이어 3장 포함)
- HabitTable/Assets.xcassets/AppIcon     라이트·다크·틴트 1024 PNG
- HabitTable/Assets.xcassets/LaunchMark  격자만(마지막 칸 비움), 147pt @2x·@3x, 라이트·다크
"""
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SVG_DIR = ROOT / "design" / "icon" / "svg"
ASSETS = ROOT / "HabitTable" / "Assets.xcassets"

# Theme.grass0~4 (라이트 / 다크)
GRASS_LIGHT = ["#E3EBDC", "#BFE3A5", "#7FCA6B", "#3FA34D", "#226F35"]
GRASS_DARK = ["#2A3A2E", "#2F5A34", "#3F8B47", "#58B85F", "#8CE07F"]
# 틴트: 단계별 밝기 16·32·50·72·100%
TINT = ["#292929", "#525252", "#808080", "#B8B8B8", "#FFFFFF"]

# 행별 단계(위→아래). None = 마지막 칸(풀 자리)
LEVELS = [[0, 1, 1, 2], [1, 1, 2, 3], [1, 2, 3, 4], [2, 3, 4, None]]
CELL_XY = [156, 340, 524, 708]
CELL, RX = 160, 46
GRID_MIN, GRID_MAX = 156, 868  # 격자 바깥 테두리 (712)

TUFT = ("M64 140 C62 100 70 60 82 22 C92 60 98 100 96 140 Z "
        "M40 140 C34 112 24 86 8 66 C34 74 56 100 66 140 Z "
        "M94 140 C104 104 124 80 152 70 C136 92 124 114 120 140 Z "
        "M36 136 C36 128 42 126 50 126 L110 126 C118 126 124 128 124 136 "
        "C124 142 120 144 114 144 L46 144 C40 144 36 142 36 136 Z")
TUFT_TRANSFORM = "translate(694 690) scale(1.2)"


def cells(colors, sheen=None):
    """격자 15칸. sheen이 있으면 칸마다 위쪽 빛을 덧댄다."""
    out = []
    for r, row in enumerate(LEVELS):
        for c, lv in enumerate(row):
            if lv is None:
                continue
            x, y = CELL_XY[c], CELL_XY[r]
            out.append(f'<rect x="{x}" y="{y}" width="{CELL}" height="{CELL}" rx="{RX}" fill="{colors[lv]}"/>')
            if sheen:
                out.append(f'<rect x="{x}" y="{y}" width="{CELL}" height="{CELL}" rx="{RX}" fill="url(#sheen)"/>')
    return "\n".join(out)


def tuft(color):
    return f'<path d="{TUFT}" fill="{color}" transform="{TUFT_TRANSFORM}"/>'


def defs(sheen=None, glow=None):
    parts = []
    if sheen:
        parts.append('<linearGradient id="sheen" x1="0" y1="0" x2="0" y2="1">'
                     f'<stop offset="0" stop-color="#FFFFFF" stop-opacity="{sheen}"/>'
                     '<stop offset="0.55" stop-color="#FFFFFF" stop-opacity="0"/></linearGradient>')
    if glow:
        parts.append('<radialGradient id="glow" cx="0.5" cy="1.08" r="0.78">'
                     f'<stop offset="0" stop-color="{glow}" stop-opacity="1"/>'
                     f'<stop offset="1" stop-color="{glow}" stop-opacity="0"/></radialGradient>')
    return f"<defs>{''.join(parts)}</defs>" if parts else ""


def svg(body, view="0 0 1024 1024", size=1024):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" '
            f'viewBox="{view}">\n{body}\n</svg>\n')


def background(glow=True):
    body = '<rect width="1024" height="1024" fill="#EEF5E8"/>'
    if glow:
        body += '\n<rect width="1024" height="1024" fill="url(#glow)"/>'
    return body


def build_svgs():
    s = {}
    # iOS 18 아이콘 (정사각형, 모서리는 시스템이 깎는다)
    s["icon-light"] = svg("\n".join([defs(sheen=0.26, glow="#D9EDC9"), background(),
                                     cells(GRASS_LIGHT, sheen=True), tuft(GRASS_LIGHT[4])]))
    s["icon-dark"] = svg("\n".join([defs(sheen=0.12), cells(GRASS_DARK, sheen=True), tuft(GRASS_DARK[4])]))
    s["icon-tinted"] = svg("\n".join([cells(TINT), tuft(TINT[4])]))
    # iOS 26 Icon Composer 레이어 (칸 위쪽 빛은 뺀다)
    s["composer-1-background"] = svg("\n".join([defs(glow="#D9EDC9"), background()]))
    s["composer-2-grid"] = svg(cells(GRASS_LIGHT))
    s["composer-3-grass"] = svg(tuft(GRASS_LIGHT[4]))
    # 실행 화면: 격자만, 마지막 칸 비움, 격자 바깥 테두리에 딱 맞춤
    view = f"{GRID_MIN} {GRID_MIN} {GRID_MAX - GRID_MIN} {GRID_MAX - GRID_MIN}"
    s["launch-light"] = svg(cells(GRASS_LIGHT), view=view, size=441)
    s["launch-dark"] = svg(cells(GRASS_DARK), view=view, size=441)
    return s


def find_chrome():
    for p in [r"C:\Program Files\Google\Chrome\Application\chrome.exe",
              r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
              shutil.which("google-chrome") or "", shutil.which("chromium") or ""]:
        if p and os.path.exists(p):
            return p
    sys.exit("Chrome/Edge를 찾지 못했어요")


def render(chrome, svg_path, size, out_png):
    """SVG를 size×size PNG로 찍는다(배경 투명)."""
    with tempfile.TemporaryDirectory() as tmp:
        html = Path(tmp) / "page.html"
        html.write_text(
            "<!doctype html><html><head><style>html,body{margin:0;background:transparent}"
            f"img{{display:block;width:{size}px;height:{size}px}}</style></head>"
            f'<body><img src="{svg_path.as_uri()}"></body></html>', encoding="utf-8")
        shot = Path(tmp) / "shot.png"
        subprocess.run([chrome, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                        "--force-device-scale-factor=1", "--default-background-color=00000000",
                        f"--window-size={size},{size}", f"--screenshot={shot}", html.as_uri()],
                       check=True, capture_output=True, timeout=60)
        img = Image.open(shot).convert("RGBA").crop((0, 0, size, size))
        img.save(out_png)


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def main():
    SVG_DIR.mkdir(parents=True, exist_ok=True)
    svgs = build_svgs()
    for name, text in svgs.items():
        write(SVG_DIR / f"{name}.svg", text)

    chrome = find_chrome()
    icon_dir = ASSETS / "AppIcon.appiconset"
    launch_dir = ASSETS / "LaunchMark.imageset"
    icon_dir.mkdir(parents=True, exist_ok=True)
    launch_dir.mkdir(parents=True, exist_ok=True)

    # 아이콘 1024
    render(chrome, SVG_DIR / "icon-light.svg", 1024, icon_dir / "AppIcon.png")
    # 라이트는 알파 없이 sRGB (App Store 규칙)
    Image.open(icon_dir / "AppIcon.png").convert("RGB").save(icon_dir / "AppIcon.png")
    render(chrome, SVG_DIR / "icon-dark.svg", 1024, icon_dir / "AppIcon-Dark.png")
    render(chrome, SVG_DIR / "icon-tinted.svg", 1024, icon_dir / "AppIcon-Tinted.png")
    # 틴트는 흑백(밝기만) + 알파
    t = Image.open(icon_dir / "AppIcon-Tinted.png").convert("LA")
    t.save(icon_dir / "AppIcon-Tinted.png")

    # 실행 화면 147pt (@2x 294, @3x 441)
    for mode in ("light", "dark"):
        suffix = "" if mode == "light" else "-Dark"
        render(chrome, SVG_DIR / f"launch-{mode}.svg", 441, launch_dir / f"LaunchMark{suffix}@3x.png")
        big = Image.open(launch_dir / f"LaunchMark{suffix}@3x.png")
        big.resize((294, 294), Image.LANCZOS).save(launch_dir / f"LaunchMark{suffix}@2x.png")

    for p in sorted(icon_dir.glob("*.png")) + sorted(launch_dir.glob("*.png")):
        im = Image.open(p)
        print(f"{p.relative_to(ROOT)}  {im.size[0]}x{im.size[1]} {im.mode}")


if __name__ == "__main__":
    main()
