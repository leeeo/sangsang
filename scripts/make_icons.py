"""상부상조 앱 아이콘 + Play 스토어 그래픽 생성기.

생성물:
  - frontend/mobile/android/app/src/main/res/mipmap-*/ic_launcher.png (5종)
  - store_assets/icon-512.png            (Play 스토어 아이콘, 512x512)
  - store_assets/feature-1024x500.png    (Play 피처 그래픽)

디자인: 인디고 그라데이션(#6366F1→#8B5CF6, 앱 요약카드와 동일) 배경 +
흰 경조사 봉투 + 금색(#EAB308) 씰.

실행: python scripts/make_icons.py  (Pillow 필요)
"""
from __future__ import annotations

import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "frontend", "mobile", "android", "app", "src", "main", "res")
OUT = os.path.join(ROOT, "store_assets")

INDIGO = (99, 102, 241)    # #6366F1
VIOLET = (139, 92, 246)    # #8B5CF6
GOLD = (234, 179, 8)       # #EAB308
WHITE = (255, 255, 255)
FLAP = (224, 231, 255)     # #E0E7FF 봉투 뚜껑(살짝 톤 다운)

MALGUN_BD = r"C:\Windows\Fonts\malgunbd.ttf"
MALGUN = r"C:\Windows\Fonts\malgun.ttf"


def _gradient(w: int, h: int, c1, c2, horizontal: bool = False) -> Image.Image:
    """대각 느낌의 선형 그라데이션."""
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            t = (x / w * 0.5 + y / h * 0.5) if not horizontal else (x / w)
            px[x, y] = tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))
    return img


def _envelope(draw: ImageDraw.ImageDraw, cx: float, cy: float, w: float) -> None:
    """중심 (cx,cy), 너비 w 봉투 (비율 고정 h=0.72w). 좌표는 캔버스 픽셀."""
    h = w * 0.72
    x0, y0, x1, y1 = cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2
    r = w * 0.06
    # 그림자
    off = w * 0.035
    draw.rounded_rectangle(
        [x0 + off, y0 + off, x1 + off, y1 + off], radius=r, fill=(0, 0, 0, 46))
    # 봉투 몸통
    draw.rounded_rectangle([x0, y0, x1, y1], radius=r, fill=WHITE)
    # 뚜껑(플랩): 위 모서리 → 중앙 아래 삼각형
    tip_y = y0 + h * 0.62
    draw.polygon([(x0, y0 + r * 0.4), (x1, y0 + r * 0.4), (cx, tip_y)], fill=FLAP)
    # 플랩 테두리 라인
    lw = max(2, int(w * 0.012))
    draw.line([(x0, y0 + r * 0.4), (cx, tip_y)], fill=(199, 210, 254), width=lw)
    draw.line([(x1, y0 + r * 0.4), (cx, tip_y)], fill=(199, 210, 254), width=lw)
    # 금색 씰
    sr = w * 0.105
    draw.ellipse([cx - sr, tip_y - sr, cx + sr, tip_y + sr], fill=GOLD)
    # 씰 하이라이트
    hr = sr * 0.45
    draw.ellipse(
        [cx - sr * 0.35 - hr, tip_y - sr * 0.35 - hr,
         cx - sr * 0.35 + hr, tip_y - sr * 0.35 + hr],
        fill=(250, 204, 21))


def make_icon(size: int) -> Image.Image:
    """정사각 런처/스토어 아이콘. 4x 슈퍼샘플 후 축소."""
    s = size * 4
    base = _gradient(s, s, INDIGO, VIOLET).convert("RGBA")
    # 배경 라운드 마스크 (22%)
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, s, s], radius=int(s * 0.22), fill=255)
    canvas = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    canvas.paste(base, (0, 0), mask)
    # 봉투 (약간 위로 — 씰이 시각 중심에 오도록)
    layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    _envelope(ImageDraw.Draw(layer), s / 2, s * 0.47, s * 0.62)
    canvas = Image.alpha_composite(canvas, layer)
    return canvas.resize((size, size), Image.LANCZOS)


def make_feature() -> Image.Image:
    """1024x500 피처 그래픽 (2x 슈퍼샘플)."""
    w, h = 2048, 1000
    img = _gradient(w, h, INDIGO, VIOLET, horizontal=True).convert("RGBA")
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    _envelope(ImageDraw.Draw(layer), w * 0.24, h * 0.5, h * 0.62)
    img = Image.alpha_composite(img, layer)
    d = ImageDraw.Draw(img)
    title_font = ImageFont.truetype(MALGUN_BD if os.path.exists(MALGUN_BD) else MALGUN, 210)
    sub_font = ImageFont.truetype(MALGUN, 74)
    tx = w * 0.44
    d.text((tx, h * 0.34), "상부상조", font=title_font, fill=WHITE, anchor="lm")
    d.text((tx, h * 0.62), "경조사비, 주고받은 마음을", font=sub_font, fill=(224, 231, 255), anchor="lm")
    d.text((tx, h * 0.74), "놓치지 않게", font=sub_font, fill=(224, 231, 255), anchor="lm")
    return img.resize((1024, 500), Image.LANCZOS)


def main() -> None:
    os.makedirs(OUT, exist_ok=True)

    # 1) 런처 아이콘 (기존 Flutter 기본 아이콘 교체)
    mipmaps = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for dpi, px in mipmaps.items():
        path = os.path.join(RES, f"mipmap-{dpi}", "ic_launcher.png")
        make_icon(px).save(path)
        print(f"[ok] {path} ({px}px)")

    # 2) Play 스토어 아이콘 512 (알파 없는 32bit 권장 → 흰 배경 없이 라운드 그대로)
    icon512 = make_icon(512)
    icon512.save(os.path.join(OUT, "icon-512.png"))
    print(f"[ok] store_assets/icon-512.png")

    # 3) 피처 그래픽 1024x500
    make_feature().convert("RGB").save(os.path.join(OUT, "feature-1024x500.png"))
    print(f"[ok] store_assets/feature-1024x500.png")


if __name__ == "__main__":
    main()
