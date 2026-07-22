"""Play 스토어용 휴대전화 스크린샷 4장 생성 (1080x1920, 9:16).

실제 Flutter 화면(home/transaction_form/relationship_list/analytics)의
레이아웃·색·구성 요소를 코드 기준으로 충실히 재현한다.

생성물: store_assets/screenshot-1-home.png ~ screenshot-4-analytics.png
실행: python scripts/make_screenshots.py
"""
from __future__ import annotations

import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "store_assets")

W, H = 1080, 1920          # 논리 크기 (출력)
S = 2                       # 슈퍼샘플 배율

# 앱 팔레트 (Flutter 코드와 동일)
INDIGO = (99, 102, 241)     # 6366F1
VIOLET = (139, 92, 246)     # 8B5CF6
BG = (241, 245, 249)        # F1F5F9
RED = (239, 68, 68)         # EF4444
RED_BG = (254, 226, 226)    # FEE2E2
GREEN = (16, 185, 129)      # 10B981
GREEN_BG = (220, 252, 231)  # DCFCE7
GREY = (120, 128, 140)
GREY_L = (156, 163, 175)
DARK = (30, 41, 59)         # 1E293B
WHITE = (255, 255, 255)

MALGUN = r"C:\Windows\Fonts\malgun.ttf"
MALGUN_BD = r"C:\Windows\Fonts\malgunbd.ttf"
EMOJI = r"C:\Windows\Fonts\seguiemj.ttf"

_fonts: dict = {}


def F(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    key = (size, bold)
    if key not in _fonts:
        path = MALGUN_BD if bold and os.path.exists(MALGUN_BD) else MALGUN
        _fonts[key] = ImageFont.truetype(path, size * S)
    return _fonts[key]


def FE(size: int) -> ImageFont.FreeTypeFont | None:
    if not os.path.exists(EMOJI):
        return None
    key = ("emoji", size)
    if key not in _fonts:
        _fonts[key] = ImageFont.truetype(EMOJI, size * S)
    return _fonts[key]


class Screen:
    """1080x1920 논리 좌표로 그리는 캔버스 (내부 2x 슈퍼샘플)."""

    def __init__(self) -> None:
        self.img = Image.new("RGB", (W * S, H * S), BG)
        self.d = ImageDraw.Draw(self.img)

    # ── 기본 도형 ─────────────────────────────────────────────
    def rect(self, box, fill):
        self.d.rectangle([c * S for c in box], fill=fill)

    def rr(self, box, r, fill, outline=None, width=1):
        self.d.rounded_rectangle([c * S for c in box], radius=r * S, fill=fill,
                                 outline=outline, width=width * S)

    def ellipse(self, box, fill):
        self.d.ellipse([c * S for c in box], fill=fill)

    def line(self, pts, fill, width=1):
        self.d.line([c * S for c in pts], fill=fill, width=max(1, width * S))

    def poly(self, pts, fill):
        self.d.polygon([(x * S, y * S) for x, y in pts], fill=fill)

    def text(self, xy, s, size, color, bold=False, anchor="la"):
        self.d.text((xy[0] * S, xy[1] * S), s, font=F(size, bold), fill=color, anchor=anchor)

    def emoji(self, xy, s, size, anchor="la"):
        f = FE(size)
        if f is None:
            return
        try:
            self.d.text((xy[0] * S, xy[1] * S), s, font=f, embedded_color=True, anchor=anchor)
        except TypeError:
            self.d.text((xy[0] * S, xy[1] * S), s, font=f, fill=DARK, anchor=anchor)

    # ── 공용 컴포넌트 ─────────────────────────────────────────
    def gradient_rr(self, box, r):
        """요약 카드용 인디고→보라 그라데이션 라운드 사각형."""
        x0, y0, x1, y1 = box
        gw, gh = int((x1 - x0) * S), int((y1 - y0) * S)
        grad = Image.new("RGB", (gw, gh))
        px = grad.load()
        for yy in range(gh):
            for xx in range(0, gw, 4):
                t = xx / gw * 0.5 + yy / gh * 0.5
                c = tuple(int(a + (b - a) * t) for a, b in zip(INDIGO, VIOLET))
                for k in range(4):
                    if xx + k < gw:
                        px[xx + k, yy] = c
        mask = Image.new("L", (gw, gh), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, gw, gh], radius=r * S, fill=255)
        self.img.paste(grad, (int(x0 * S), int(y0 * S)), mask)

    def status_bar(self, color=INDIGO, light=True):
        self.rect([0, 0, W, 66], color)
        fg = WHITE if light else DARK
        self.text((36, 20), "9:41", 24, fg, bold=True)
        # 배터리/신호 아이콘 간략화
        self.rr([W - 100, 26, W - 48, 50], 6, None, outline=fg, width=2)
        self.rect([W - 96, 31, W - 96 + 38, 45], fg)
        self.rect([W - 46, 33, W - 42, 43], fg)

    def app_bar(self, title, subtitle=None, right_icon=None):
        h = 200 if subtitle else 170
        self.rect([0, 0, W, h], INDIGO)
        self.status_bar()
        if subtitle:
            self.text((44, 92), title, 33, WHITE, bold=True)
            self.text((44, 146), subtitle, 24, (224, 231, 255))
        else:
            self.text((44, 100), title, 36, WHITE, bold=True)
        if right_icon == "logout":
            pass
        if right_icon == "plus":
            cx, cy = W - 70, 118
            self.rect([cx - 22, cy - 3, cx + 22, cy + 3], WHITE)
            self.rect([cx - 3, cy - 22, cx + 3, cy + 22], WHITE)
        return h

    def save(self, name: str):
        out = self.img.resize((W, H), Image.LANCZOS)
        os.makedirs(OUT, exist_ok=True)
        p = os.path.join(OUT, name)
        out.save(p)
        print(f"[ok] {p}")


# ── 아이콘 (간단 벡터) ─────────────────────────────────────────


def icon_people(s: Screen, cx, cy, c, r=16):
    s.ellipse([cx - r * 0.9, cy - r, cx - r * 0.9 + r, cy - r + r], c)
    s.ellipse([cx + r * 0.1, cy - r * 0.8, cx + r * 0.1 + r * 0.9, cy - r * 0.8 + r * 0.9], c)
    s.d.pieslice([(cx - r * 1.4) * S, (cy + r * 0.15) * S, (cx + r * 0.6) * S, (cy + r * 1.9) * S], 180, 360, fill=c)
    s.d.pieslice([(cx - r * 0.2) * S, (cy + r * 0.3) * S, (cx + r * 1.5) * S, (cy + r * 1.8) * S], 180, 360, fill=c)


def icon_chart(s: Screen, cx, cy, c, r=16):
    s.rr([cx - r, cy + r * 0.1, cx - r * 0.5, cy + r], 2, c)
    s.rr([cx - r * 0.25, cy - r * 0.5, cx + r * 0.25, cy + r], 2, c)
    s.rr([cx + r * 0.5, cy - r, cx + r, cy + r], 2, c)


def icon_arrow(s: Screen, cx, cy, c, up=True, r=12):
    if up:
        s.poly([(cx, cy - r), (cx - r * 0.75, cy - r * 0.1), (cx + r * 0.75, cy - r * 0.1)], c)
        s.rect([cx - 3, cy - r * 0.15, cx + 3, cy + r], c)
    else:
        s.poly([(cx, cy + r), (cx - r * 0.75, cy + r * 0.1), (cx + r * 0.75, cy + r * 0.1)], c)
        s.rect([cx - 3, cy - r, cx + 3, cy + r * 0.15], c)


def icon_calendar(s: Screen, cx, cy, c, r=14):
    s.rr([cx - r, cy - r * 0.8, cx + r, cy + r], 3, None, outline=c, width=2)
    s.line([cx - r, cy - r * 0.3, cx + r, cy - r * 0.3], c, 2)
    s.rect([cx - r * 0.5, cy - r * 1.1, cx - r * 0.3, cy - r * 0.6], c)
    s.rect([cx + r * 0.3, cy - r * 1.1, cx + r * 0.5, cy - r * 0.6], c)


def chevron(s: Screen, cx, cy, c, right=True, r=10):
    if right:
        s.line([cx - r * 0.4, cy - r, cx + r * 0.5, cy, cx - r * 0.4, cy + r], c, 3)
    else:
        s.line([cx + r * 0.4, cy - r, cx - r * 0.5, cy, cx + r * 0.4, cy + r], c, 3)


# ── 화면 1: 홈 ────────────────────────────────────────────────


def screen_home():
    s = Screen()
    s.app_bar("안녕하세요, 어진님", "2026년 7월")

    # 요약 카드
    s.gradient_rr([44, 250, W - 44, 560], 26)
    s.text((88, 296), "이번 달 잔액", 24, (224, 231, 255))
    s.text((88, 345), "+₩230,000", 58, WHITE, bold=True)
    for i, (label, val) in enumerate([("수입", "₩380,000"), ("지출", "₩150,000")]):
        x0 = 88 + i * 452
        s.rr([x0, 460, x0 + 420, 535], 15, (255, 255, 255, 30))
        s.d.rounded_rectangle([x0 * S, 460 * S, (x0 + 420) * S, 535 * S], radius=15 * S,
                              fill=tuple(int(c * 0.88 + w * 0.12) for c, w in zip(INDIGO if i == 0 else VIOLET, WHITE)))
        s.text((x0 + 24, 472), label, 20, (224, 231, 255))
        s.text((x0 + 24, 500), val, 26, WHITE, bold=True)

    # 빠른 메뉴
    for i, (label, icon) in enumerate([("관계 관리", "people"), ("분석", "chart")]):
        x0 = 44 + i * 508
        s.rr([x0, 600, x0 + 484, 740], 16, WHITE)
        if icon == "people":
            icon_people(s, x0 + 242, 650, INDIGO)
        else:
            icon_chart(s, x0 + 242, 655, INDIGO)
        s.text((x0 + 242, 690), label, 23, DARK, anchor="ma")

    # 최근 거래
    s.text((44, 790), "최근 거래", 28, DARK, bold=True)
    s.text((W - 44, 795), "전체 보기", 23, INDIGO, anchor="ra")

    rows = [
        ("김민수", "07.12", "+₩100,000", False),
        ("박서연", "07.08", "-₩50,000", True),
        ("이하늘", "07.02", "+₩80,000", False),
    ]
    y = 850
    for name, date, amt, is_exp in rows:
        s.rr([44, y, W - 44, y + 128], 16, WHITE)
        box_c = RED_BG if is_exp else GREEN_BG
        arr_c = RED if is_exp else GREEN
        s.rr([72, y + 28, 72 + 72, y + 100], 16, box_c)
        icon_arrow(s, 108, y + 64, arr_c, up=is_exp)
        s.text((170, y + 32), name, 25, DARK, bold=True)
        s.text((170, y + 74), date, 20, GREY_L)
        s.text((W - 76, y + 50), amt, 26, arr_c, bold=True, anchor="ra")
        y += 144

    # FAB
    s.rr([W - 340, H - 200, W - 44, H - 108], 46, INDIGO)
    s.rect([W - 296, H - 157, W - 256, H - 151], WHITE)
    s.rect([W - 279, H - 174, W - 273, H - 134], WHITE)
    s.text((W - 230, H - 172), "거래 등록", 27, WHITE, bold=True)

    s.save("screenshot-1-home.png")


# ── 화면 2: 거래 등록 ─────────────────────────────────────────


def screen_form():
    s = Screen()
    s.app_bar("거래 등록")

    # 지출/수입 토글
    s.rr([44, 220, W - 44, 330], 16, WHITE)
    s.rr([56, 232, W / 2 - 6, 318], 14, RED)
    s.text(((56 + W / 2 - 6) / 2, 258), "지출", 26, WHITE, bold=True, anchor="ma")
    s.text(((W / 2 + W - 56) / 2, 258), "수입", 26, GREY_L, anchor="ma")

    # 카드 1: 금액/날짜/카테고리
    s.rr([44, 370, W - 44, 850], 20, WHITE)
    s.text((80, 400), "금액", 21, GREY_L)
    s.text((80, 440), "100,000", 46, DARK, bold=True)
    s.text((W - 80, 462), "원", 26, GREY, anchor="ra")
    s.line([80, 530, W - 80, 530], (238, 242, 247), 2)
    s.text((80, 550), "날짜", 21, GREY_L)
    icon_calendar(s, 98, 615, GREY)
    s.text((135, 596), "2026년 7월 21일", 26, DARK)
    chevron(s, W - 95, 612, GREY_L)
    s.line([80, 670, W - 80, 670], (238, 242, 247), 2)
    s.text((80, 690), "카테고리", 21, GREY_L)
    s.emoji((80, 732), "💍", 28)
    s.text((135, 736), "결혼 축의금", 26, DARK)
    s.poly([(W - 105, 748), (W - 75, 748), (W - 90, 768)], GREY_L)

    # 카드 2: 상대방/유형/메모
    s.rr([44, 890, W - 44, 1360], 20, WHITE)
    s.text((80, 920), "상대방 이름", 21, GREY_L)
    s.text((80, 960), "김민수", 26, DARK)
    s.line([80, 1020, W - 80, 1020], (238, 242, 247), 2)
    s.text((80, 1040), "경조사 유형", 21, GREY_L)
    s.emoji((80, 1082), "💍", 28)
    s.text((135, 1086), "결혼식", 26, DARK)
    s.poly([(W - 105, 1098), (W - 75, 1098), (W - 90, 1118)], GREY_L)
    s.line([80, 1150, W - 80, 1150], (238, 242, 247), 2)
    s.text((80, 1170), "메모", 21, GREY_L)
    s.text((80, 1210), "축하합니다! 결혼식 축의금", 26, DARK)

    # 등록 버튼
    s.rr([44, 1420, W - 44, 1524], 20, INDIGO)
    s.text((W / 2, 1448), "등록", 30, WHITE, bold=True, anchor="ma")

    s.save("screenshot-2-form.png")


# ── 화면 3: 관계 관리 ─────────────────────────────────────────


def screen_relationships():
    s = Screen()
    s.app_bar("관계 관리", right_icon="plus")

    rows = [
        ("김민수", "친구", "₩70,000", "내가 더 줌", True, "줌 ₩100,000", "받음 ₩30,000", "최근 26.07.12"),
        ("박서연", "직장 동료", "₩50,000", "내가 더 받음", False, "줌 ₩50,000", "받음 ₩100,000", "최근 26.07.08"),
        ("이하늘", "가족", "₩80,000", "내가 더 받음", False, "줌 ₩0", "받음 ₩80,000", "최근 26.07.02"),
        ("정우성", "대학 동기", "", "정산 완료", None, "줌 ₩50,000", "받음 ₩50,000", "최근 26.06.15"),
    ]
    y = 230
    for name, rtype, bal, bal_label, gave_more, chip1, chip2, last in rows:
        s.rr([44, y, W - 44, y + 250], 16, WHITE)
        # 아바타
        s.ellipse([80, y + 34, 160, y + 114], (231, 233, 253))
        s.text((120, y + 52), name[0], 30, INDIGO, bold=True, anchor="ma")
        s.text((186, y + 38), name, 27, DARK, bold=True)
        s.text((186, y + 84), rtype, 21, GREY_L)
        if gave_more is None:
            s.text((W - 84, y + 58), bal_label, 23, GREY_L, anchor="ra")
        else:
            c = RED if gave_more else GREEN
            s.text((W - 84, y + 40), bal, 27, c, bold=True, anchor="ra")
            s.text((W - 84, y + 88), bal_label, 19, c, anchor="ra")
        s.line([80, y + 140, W - 80, y + 140], (241, 245, 249), 2)
        # 칩
        c1w = 30 + len(chip1) * 13
        s.rr([80, y + 168, 80 + c1w, y + 218], 25, (254, 236, 236))
        s.text((80 + c1w / 2, y + 180), chip1, 20, RED, anchor="ma")
        x2 = 80 + c1w + 16
        c2w = 30 + len(chip2) * 13
        s.rr([x2, y + 168, x2 + c2w, y + 218], 25, (228, 250, 240))
        s.text((x2 + c2w / 2, y + 180), chip2, 20, GREEN, anchor="ma")
        s.text((W - 84, y + 184), last, 19, GREY_L, anchor="ra")
        y += 268

    s.save("screenshot-3-relationships.png")


# ── 화면 4: 분석 ─────────────────────────────────────────────


def screen_analytics():
    s = Screen()
    # 앱바 + 탭
    s.rect([0, 0, W, 250], INDIGO)
    s.status_bar()
    s.text((44, 96), "분석", 36, WHITE, bold=True)
    s.text((W / 4, 180), "월별 요약", 26, WHITE, bold=True, anchor="ma")
    s.text((W * 3 / 4, 180), "트렌드", 26, (199, 205, 255), anchor="ma")
    s.rect([0, 244, W / 2, 250], WHITE)

    # 월 선택
    chevron(s, 330, 330, GREY, right=False)
    s.text((W / 2, 305), "2026년 7월", 32, DARK, bold=True, anchor="ma")
    chevron(s, W - 330, 330, GREY_L)

    # 요약 카드
    s.rr([44, 400, W - 44, 640], 20, WHITE)
    third = (W - 88) / 3
    for i, (label, val, c) in enumerate([
        ("수입", "+₩380,000", GREEN),
        ("지출", "-₩150,000", RED),
        ("잔액", "+₩230,000", INDIGO),
    ]):
        cx = 44 + third * i + third / 2
        s.text((cx, 448), label, 22, GREY_L, anchor="ma")
        s.text((cx, 510), val, 27, c, bold=True, anchor="ma")
        if i < 2:
            s.line([44 + third * (i + 1), 440, 44 + third * (i + 1), 600], (241, 245, 249), 2)

    # 카테고리별 지출
    s.text((44, 700), "카테고리별 지출", 28, DARK, bold=True)
    # 지출/수입 토글 pill
    s.rr([W - 300, 692, W - 44, 752], 30, (231, 233, 253))
    s.rr([W - 300, 692, W - 176, 752], 30, INDIGO)
    s.text((W - 238, 706), "지출", 21, WHITE, anchor="ma")
    s.text((W - 110, 706), "수입", 21, INDIGO, anchor="ma")

    cats = [
        ("결혼 축의금", "₩100,000", 0.67, (255, 107, 157)),
        ("장례 조의금", "₩50,000", 0.33, (107, 114, 128)),
    ]
    y = 800
    s.rr([44, y - 30, W - 44, y + len(cats) * 150 + 10], 20, WHITE)
    for name, amt, ratio, color in cats:
        s.text((84, y + 6), name, 24, DARK, bold=True)
        s.text((W - 84, y + 6), f"{amt}  ·  {int(ratio * 100)}%", 23, GREY, anchor="ra")
        s.rr([84, y + 56, W - 84, y + 80], 12, (241, 245, 249))
        s.rr([84, y + 56, 84 + (W - 168) * ratio, y + 80], 12, color)
        y += 150

    s.save("screenshot-4-analytics.png")


if __name__ == "__main__":
    screen_home()
    screen_form()
    screen_relationships()
    screen_analytics()
