# -*- coding: utf-8 -*-
"""Pure-Pillow render of SignalVeil App Store screenshots (1290x2796 iPhone 6.7").

Same output as the Playwright version, but no browser dependency.
Each PNG is a marketing strip on top + an iPhone frame with SwiftUI-look cards.
"""
import os, pathlib, sys
from PIL import Image, ImageDraw, ImageFont

OUT = pathlib.Path(__file__).parent / "out"
OUT.mkdir(parents=True, exist_ok=True)

W, H = 1290, 2796

# ---- Fonts (Windows) ----
F_BOLD_HUGE  = "C:/Windows/Fonts/segoeuib.ttf"
F_BOLD       = "C:/Windows/Fonts/segoeuib.ttf"
F_REG        = "C:/Windows/Fonts/segoeui.ttf"
F_LIGHT      = "C:/Windows/Fonts/segoeuil.ttf"
F_EMOJI      = "C:/Windows/Fonts/seguiemj.ttf"

def F(path, size):
    return ImageFont.truetype(path, size)

# ---- Colors ----
PURPLE_DARK = (62, 49, 96)
PURPLE_MID  = (90, 74, 130)
PURPLE_LITE = (139, 122, 184)
PURPLE_BG   = (240, 235, 245)
PURPLE_BG2  = (232, 223, 241)
BG          = (242, 242, 247)
WHITE       = (255, 255, 255)
BLACK       = (28, 28, 30)
MUTED       = (142, 142, 147)
GREEN       = (31, 122, 54)
RED         = (201, 42, 31)
GOLD        = (245, 197, 106)
TINT_RED    = (255, 245, 245)
BORDER_RED  = (255, 217, 212)
BORDER_LITE = (229, 229, 234)
BORDER_PURP = (201, 184, 224)

# ---- Helpers ----

def text_w(draw, s, font):
    bbox = draw.textbbox((0, 0), s, font=font)
    return bbox[2] - bbox[0], bbox[3] - bbox[1]

def draw_text_centered(draw, xy, s, font, fill):
    x, y = xy
    w, h = text_w(draw, s, font)
    draw.text((x - w // 2, y - h // 2), s, font=font, fill=fill)
    return w, h

def round_rect(draw, xy, r, fill=None, outline=None, width=1):
    draw.rounded_rectangle(xy, radius=r, fill=fill, outline=outline, width=width)

def gradient_bg(img, top, bottom, box):
    """Simple vertical gradient."""
    x0, y0, x1, y1 = box
    h = y1 - y0
    for i in range(h):
        t = i / max(1, h - 1)
        c = tuple(int(top[k] + (bottom[k] - top[k]) * t) for k in range(3))
        draw = ImageDraw.Draw(img)
        draw.line([(x0, y0 + i), (x1, y0 + i)], fill=c)

# ---- Building blocks ----

def make_marketing_strip(title, accent_words=()):
    """Top 760px marketing band."""
    img = Image.new("RGB", (W, 760), color=PURPLE_DARK)
    # gradient
    for y in range(760):
        t = y / 759
        r = int(31  + (139 - 31)  * t)
        g = int(24  + (122 - 24)  * t)
        b = int(48  + (184 - 48)  * t)
        ImageDraw.Draw(img).line([(0, y), (W, y)], fill=(r, g, b))
    d = ImageDraw.Draw(img)

    # accent color words — title is plain string, accents highlighted by re-drawing yellow
    # For simplicity render title as a single line (huge), with manual word highlighting
    # We'll split on space to find accent words; rebuild line by line.

    # Eyebrow
    eyebrow_font = F(F_LIGHT, 36)
    d.text((80, 96), title, font=eyebrow_font, fill=(255, 255, 255, 200))

    # H1: lines as list of (text, accent_bool)
    return img  # we'll draw h1 in caller to keep accent logic

def draw_marketing_full(eyebrow, lines, sub, accent_color=GOLD):
    """Compose the full top marketing band. `lines` is list of (text, [start,end] accent ranges)."""
    img = Image.new("RGB", (W, 760))
    for y in range(760):
        t = y / 759
        r = int(31  + (139 - 31)  * t)
        g = int(24  + (122 - 24)  * t)
        b = int(48  + (184 - 48)  * t)
        ImageDraw.Draw(img).line([(0, y), (W, y)], fill=(r, g, b))
    d = ImageDraw.Draw(img)

    # eyebrow
    ef = F(F_LIGHT, 36)
    d.text((80, 100), eyebrow.upper(), font=ef, fill=(255, 255, 255))
    # also draw subtle light overlay
    d2 = ImageDraw.Draw(img, "RGBA")
    d2.text((80, 100), eyebrow.upper(), font=ef, fill=(255, 255, 255, 200))

    # h1 lines
    y_cursor = 190
    line_h = 130
    for line_text, accents in lines:
        hf = F(F_BOLD_HUGE, 124)
        # Draw word by word so we can color accents
        x = 80
        words = line_text.split(" ")
        for w in words:
            color = accent_color if any(s <= x < s for (s, e) in accents) else WHITE
            tw, th = text_w(d, w + " ", hf)
            d.text((x, y_cursor), w + " ", font=hf, fill=color)
            x += tw
        y_cursor += line_h + 6

    # gold divider
    d2 = ImageDraw.Draw(img)
    d2.rectangle([(80, y_cursor + 10), (80 + 220, y_cursor + 16)], fill=GOLD)

    # sub
    sf = F(F_REG, 44)
    y_cursor += 50
    for sub_line in sub.split("<br>"):
        d.text((80, y_cursor), sub_line, font=sf, fill=(255, 255, 255, 235))
        y_cursor += 60
    return img

# ---- Phone (bottom) ----

def make_phone_area(card_painter):
    """Build the bottom 2036px area with iPhone frame + cards drawn by card_painter(draw, x0, y0, width)."""
    area = Image.new("RGB", (W, 2036), color=BG)
    d = ImageDraw.Draw(area)

    # iPhone outer frame (centered, 1100 wide)
    phone_w = 1100
    phone_x = (W - phone_w) // 2
    phone_y = 60
    phone_h = 1900

    # outer black bezel
    round_rect(d, (phone_x - 14, phone_y - 14, phone_x + phone_w + 14, phone_y + phone_h + 14),
               r=70, fill=BLACK)
    # white screen
    round_rect(d, (phone_x, phone_y, phone_x + phone_w, phone_y + phone_h),
               r=60, fill=WHITE)

    # notch
    d2 = ImageDraw.Draw(area)
    notch_w = 360
    d2.rounded_rectangle(
        [(phone_x + (phone_w - notch_w) // 2, phone_y - 2),
         (phone_x + (phone_w + notch_w) // 2, phone_y + 36)],
        radius=18, fill=BLACK)

    # status bar text
    sf = F(F_BOLD, 26)
    d.text((phone_x + 50, phone_y + 22), "9:41", font=sf, fill=BLACK)
    # right side: simple icons (Wi-Fi + battery drawn)
    bx = phone_x + phone_w - 50
    d.text((bx - 60, phone_y + 22), "5G", font=sf, fill=BLACK)
    # battery
    d.rounded_rectangle([(bx - 8, phone_y + 30), (bx + 50, phone_y + 56)], radius=4, outline=BLACK, width=2)
    d.rectangle([(bx + 50, phone_y + 36), (bx + 54, phone_y + 50)], fill=BLACK)

    # hand off to card painter; card area starts below status bar
    inner_y = phone_y + 76
    inner_x = phone_x + 36
    inner_w = phone_w - 72
    card_painter(area, inner_x, inner_y, inner_w)

    return area

# ---- Card helpers (operate on PIL Image + draw) ----

def card(d, x, y, w, h, fill=WHITE, border=BORDER_LITE, border_w=1, radius=22):
    round_rect(d, (x, y, x + w, y + h), r=radius, fill=fill, outline=border, width=border_w)
    return x, y, w, h

def badge_pill(d, x, y, text, fg, bg, font_size=26, border=None, emoji_prefix=""):
    f = F(F_BOLD, font_size)
    label = emoji_prefix + text if emoji_prefix else text
    tw, th = text_w(d, label, f)
    pad_x, pad_y = 18, 8
    bx0, by0 = x, y
    bx1, by1 = x + tw + pad_x * 2, y + th + pad_y * 2
    round_rect(d, (bx0, by0, bx1, by1), r=999, fill=bg, outline=border, width=2 if border else 0)
    d.text((bx0 + pad_x, by0 + pad_y - 2), label, font=f, fill=fg)
    return bx1, by1

# ---- Per-screenshot composers ----

def draw_status_loading(d, x, y, w, h, message):
    """Banner 'Today's noise: X of Y metrics' (veil purple)."""
    f1 = F(F_BOLD, 44)
    f2 = F(F_REG, 32)
    # gradient
    for i in range(h):
        t = i / max(1, h - 1)
        r = int(78  + (111 - 78)  * t)
        g = int(63  + (94  - 63)  * t)
        b = int(112 + (150 - 112) * t)
        d.line([(x, y + i), (x + w, y + i)], fill=(r, g, b))
    round_rect(d, (x, y, x + w, y + h), r=24, fill=None)
    # bell icon (simple)
    d.text((x + 28, y + 24), "🔕", font=F(F_EMOJI, 56), fill=WHITE)
    d.text((x + 110, y + 24), message, font=f1, fill=WHITE)

# ============ Screenshots ============

def screenshot_1_quiet_mode():
    top = draw_marketing_full(
        eyebrow="SignalVeil · Quiet Mode",
        lines=[("Mute the noise.", [(0, 0)]),
               ("One tap.",        [(0, 0)])],
        sub="Three Declutter Bundles. Free for every user.<br>Whole categories of wearable anxiety, gone.",
        accent_color=GOLD,
    )

    def paint(area, x, y, w):
        d = ImageDraw.Draw(area)

        # Header card (purple-soft)
        card_h = 150
        for i in range(card_h):
            t = i / (card_h - 1)
            r = int(240 + (232 - 240) * t)
            g = int(235 + (223 - 235) * t)
            b = int(245 + (241 - 245) * t)
            d.line([(x, y + i), (x + w, y + i)], fill=(r, g, b))
        round_rect(d, (x, y, x + w, y + card_h), r=24, fill=None, outline=BORDER_PURP, width=2)
        d.text((x + 28, y + 24), "Quiet Mode", font=F(F_BOLD, 50), fill=PURPLE_DARK)
        d.text((x + 28, y + 88), "Mute entire categories of wearable noise.", font=F(F_REG, 32), fill=MUTED)

        # Section title
        cy = y + card_h + 36
        d.text((x, cy), "Quick Declutter Bundles", font=F(F_BOLD, 44), fill=BLACK)
        d.text((x, cy + 56), "Tap to ignore the whole bundle.", font=F(F_REG, 28), fill=MUTED)

        # 3 bundle cards
        bundles = [
            ("Oura Anxiety Kit",
             "Readiness, Stress, Resilience — single-day noise that creates anxiety.",
             "3 items"),
            ("Apple Watch Pressure",
             "Stand, Move, Exercise ring reminders — pressure, not health.",
             "3 items"),
            ("Fitness Score Overload",
             "Whoop strain, Athlytic recovery — focus on how you feel, not the number.",
             "3 items"),
        ]
        cy += 110
        for title, desc, items in bundles:
            ch = 200
            card(d, x, cy, w, ch, fill=WHITE)
            d.text((x + 28, cy + 24), title, font=F(F_BOLD, 40), fill=BLACK)
            # word-wrap desc
            words = desc.split(" ")
            line, lines = "", []
            for wd in words:
                if text_w(d, line + " " + wd, F(F_REG, 28))[0] > w - 200:
                    lines.append(line.strip()); line = wd
                else:
                    line += " " + wd
            if line.strip(): lines.append(line.strip())
            for li, ln in enumerate(lines[:2]):
                d.text((x + 28, cy + 80 + li * 36), ln, font=F(F_REG, 28), fill=MUTED)
            d.text((x + 28, cy + ch - 50), items, font=F(F_BOLD, 26), fill=PURPLE_MID)
            # plus circle
            d.ellipse([(x + w - 90, cy + (ch - 80) // 2), (x + w - 30, cy + (ch - 80) // 2 + 60)],
                      outline=PURPLE_MID, width=4)
            d.line([(x + w - 75, cy + (ch - 80) // 2 + 30), (x + w - 45, cy + (ch - 80) // 2 + 30)], fill=PURPLE_MID, width=4)
            d.line([(x + w - 60, cy + (ch - 80) // 2 + 15), (x + w - 60, cy + (ch - 80) // 2 + 45)], fill=PURPLE_MID, width=4)
            cy += ch + 18

    bottom = make_phone_area(paint)
    final = Image.new("RGB", (W, H), color=BG)
    final.paste(top, (0, 0))
    final.paste(bottom, (0, 760))
    return final

def screenshot_2_conflict():
    top = draw_marketing_full(
        eyebrow="SignalVeil · Conflict Arbitrator",
        lines=[("When the watch",   [(10, 70)]),
               ("disagrees with you,", [(0, 0)]),
               ("we side with you.",  [(16, 50)])],
        sub="If your device says recover but you feel fine,<br>single-day scores are noise. We trust how you feel.",
        accent_color=GOLD,
    )

    def paint(area, x, y, w):
        d = ImageDraw.Draw(area)
        # Header date card (purple-soft) - dark purple gradient with white text
        ch = 130
        for i in range(ch):
            t = i / (ch - 1)
            r = int(78  + (111 - 78)  * t); g = int(63  + (94  - 63)  * t); b = int(112 + (150 - 112) * t)
            d.line([(x, y + i), (x + w, y + i)], fill=(r, g, b))
        round_rect(d, (x, y, x + w, y + ch), r=20)
        d.text((x + 28, y + 22), "TODAY · FRI AUG 28", font=F(F_BOLD, 26), fill=(255, 255, 255))
        d.text((x + 28, y + 60), "3 of 8 metrics flagged as noise.", font=F(F_REG, 30), fill=(255, 255, 255))

        # Conflict card (light purple soft with thick border)
        cy = y + ch + 28
        ch2 = 440
        for i in range(ch2):
            t = i / (ch2 - 1)
            r = int(240 + (232 - 240) * t)
            g = int(235 + (223 - 235) * t)
            b = int(245 + (241 - 245) * t)
            d.line([(x, cy + i), (x + w, cy + i)], fill=(r, g, b))
        round_rect(d, (x, cy, x + w, cy + ch2), r=24, outline=PURPLE_LITE, width=3)
        # Drawn scale icon (no emoji)
        scx, scy, sr = x + 60, cy + 60, 28
        d.line([(scx - sr, scy), (scx + sr, scy)], fill=PURPLE_DARK, width=4)
        d.line([(scx, scy - sr - 8), (scx, scy + 4)], fill=PURPLE_DARK, width=4)
        d.line([(scx - 10, scy + 4), (scx + 10, scy + 4)], fill=PURPLE_DARK, width=4)
        d.rounded_rectangle([(scx - sr, scy + 4), (scx - 8, scy + 20)], radius=2, outline=PURPLE_DARK, width=2)
        d.rounded_rectangle([(scx + 8, scy + 4), (scx + sr, scy + 20)], radius=2, outline=PURPLE_DARK, width=2)
        d.text((x + 120, cy + 36), "Trust your body", font=F(F_BOLD, 42), fill=PURPLE_DARK)
        badge_pill(d, x + w - 200, cy + 28, "YOU", WHITE, PURPLE_MID, font_size=26)
        d.text((x + 28, cy + 120), "Watch said:", font=F(F_REG, 30), fill=MUTED)
        d.text((x + 240, cy + 120), "Recovery 64 (low)", font=F(F_BOLD, 30), fill=(58, 47, 78))
        d.text((x + 28, cy + 170), "You said:", font=F(F_REG, 30), fill=MUTED)
        d.text((x + 240, cy + 170), "Feeling good", font=F(F_BOLD, 30), fill=(58, 47, 78))
        # divider
        d.line([(x + 28, cy + 230), (x + w - 28, cy + 230)], fill=PURPLE_LITE, width=2)
        d.text((x + 28, cy + 254), '"Single-day scores are unreliable. You feel good —', font=F(F_BOLD, 32), fill=PURPLE_DARK)
        d.text((x + 28, cy + 294), "that's the real signal. Ignore this one.\"", font=F(F_BOLD, 32), fill=PURPLE_DARK)
        d.text((x + 28, cy + 354), "Rule: 3+ day anomaly overrides.", font=F(F_REG, 24), fill=MUTED)

        # "No conflict" small badge with drawn checkmark
        cy2 = cy + ch2 + 22
        ch3 = 100
        round_rect(d, (x, cy2, x + w, cy2 + ch3), r=16, fill=WHITE)
        cmx, cmy = x + 52, cy2 + ch3 // 2
        d.line([(cmx - 18, cmy), (cmx - 4, cmy + 16), (cmx + 22, cmy - 18)], fill=GREEN, width=6)
        d.text((x + 90, cy2 + 32), "No trend anomaly today. Trust your body.", font=F(F_REG, 28), fill=(58, 47, 78))

    bottom = make_phone_area(paint)
    final = Image.new("RGB", (W, H), color=BG)
    final.paste(top, (0, 0))
    final.paste(bottom, (0, 760))
    return final

def screenshot_3_today_noise():
    top = draw_marketing_full(
        eyebrow="SignalVeil · Signal vs Noise",
        lines=[("Single-day is noise.", [(15, 65)]),
               ("Trends are signal.",   [(0, 0)])],
        sub="Every metric is judged by a deterministic rule engine.<br>Loud NOISE badges tell you what to skip — not chase.",
        accent_color=GOLD,
    )

    def paint(area, x, y, w):
        d = ImageDraw.Draw(area)
        # Veil purple header (brief)
        ch = 180
        for i in range(ch):
            t = i / (ch - 1)
            r = int(78  + (111 - 78)  * t); g = int(63  + (94  - 63)  * t); b = int(112 + (150 - 112) * t)
            d.line([(x, y + i), (x + w, y + i)], fill=(r, g, b))
        round_rect(d, (x, y, x + w, y + ch), r=24)
        d.text((x + 28, y + 24), "TODAY · AUG 28", font=F(F_BOLD, 26), fill=(255, 255, 255))
        d.text((x + 28, y + 64), "Morning Brief", font=F(F_BOLD, 44), fill=WHITE)
        d.text((x + 28, y + 124), "Your 7-day HRV is up 4%. Sleep is stable.", font=F(F_REG, 30), fill=(255, 255, 255))
        d.text((x + 28, y + 158), "5 of 8 metrics are noise today.", font=F(F_REG, 30), fill=GOLD)

        # Section title
        cy = y + ch + 28
        d.text((x, cy), "Today's Metrics", font=F(F_BOLD, 40), fill=BLACK)
        cy += 60

        # Signal rows
        def row(title, meta, badge_text, badge_fg, badge_bg, tint_white=False, fill=WHITE, border=BORDER_LITE):
            nonlocal cy
            rh = 130
            card(d, x, cy, w, rh, fill=fill, border=border)
            d.text((x + 28, cy + 22), title, font=F(F_BOLD, 34), fill=BLACK)
            d.text((x + 28, cy + 70), meta, font=F(F_REG, 26), fill=MUTED)
            badge_pill(d, x + w - 260, cy + 36, badge_text, badge_fg, badge_bg, font_size=24)
            cy += rh + 14

        row("HRV",        "7d avg: 58 ms · trending up",        "↑ +4%",   GREEN, (220, 244, 230))
        row("Sleep",      "7d avg: 7.2 h · stable",             "STABLE",  GREEN, (220, 244, 230))
        row("Recovery Score", "Yesterday: 64 · single day",     "NOISE",   RED,   (255, 232, 230), border=(255, 200, 195), fill=TINT_RED)
        row("Oura Readiness", "Yesterday: 71 · single day",     "NOISE",   RED,   (255, 232, 230), border=(255, 200, 195), fill=TINT_RED)

    bottom = make_phone_area(paint)
    final = Image.new("RGB", (W, H), color=BG)
    final.paste(top, (0, 0))
    final.paste(bottom, (0, 760))
    return final

def screenshot_4_verdict():
    top = draw_marketing_full(
        eyebrow="SignalVeil · Verdict",
        lines=[("Verdict: NOISE.",  [(9, 60)]),
               ("Skip it.",         [(0, 0)])],
        sub="Each metric gets one of two verdicts, decided by code, not AI.<br>No black boxes.",
        accent_color=GOLD,
    )

    def paint(area, x, y, w):
        d = ImageDraw.Draw(area)
        # Big NOISE verdict card
        ch = 260
        for i in range(ch):
            t = i / (ch - 1)
            r = int(240 + (232 - 240) * t); g = int(235 + (223 - 235) * t); b = int(245 + (241 - 245) * t)
            d.line([(x, y + i), (x + w, y + i)], fill=(r, g, b))
        round_rect(d, (x, y, x + w, y + ch), r=24, outline=PURPLE_LITE, width=3)
        d.text((x + 28, y + 24), "VERDICT", font=F(F_BOLD, 26), fill=MUTED)
        # Drawn "muted bell" icon (no emoji dependency)
        # bell body
        bx, by, br = x + 100, y + 100, 44
        d.ellipse([(bx - br, by - br), (bx + br, by + br)], fill=PURPLE_DARK)
        # diagonal mute slash
        d.line([(bx - br - 6, by + br + 4), (bx + br + 6, by - br - 4)], fill=(255, 255, 255), width=10)
        d.line([(bx - br - 6, by + br + 4), (bx + br + 6, by - br - 4)], fill=RED, width=6)
        d.text((x + 200, y + 80), "NOISE", font=F(F_BOLD_HUGE, 90), fill=PURPLE_DARK)
        d.text((x + 200, y + 190), "Safe to ignore today.", font=F(F_BOLD, 32), fill=PURPLE_MID)

        # Trend sparkline card
        cy = y + ch + 28
        ch2 = 360
        card(d, x, cy, w, ch2, fill=WHITE)
        d.text((x + 28, cy + 24), "Oura Readiness", font=F(F_BOLD, 36), fill=BLACK)
        d.text((x + 28, cy + 70), "Last 7 days", font=F(F_REG, 26), fill=MUTED)
        # Sparkline in RELATIVE coordinates (x+28 .. x+w-28, cy+110 .. cy+260)
        base_x, base_y = x + 28, cy + 130
        span_x, span_y = w - 56, 140
        # 7 days, sample y as proportions (lower=better, so high values rendered lower)
        # data points: scores like 65, 60, 68, 72, 66, 64, 70 → normalized
        raw = [0.45, 0.65, 0.40, 0.20, 0.35, 0.55, 0.30]
        pts = [(base_x + int(i / 6 * span_x), base_y + int(v * span_y)) for i, v in enumerate(raw)]
        # baseline reference (middle)
        ref_y = base_y + int(0.5 * span_y)
        d.line([(base_x, ref_y), (base_x + span_x, ref_y)], fill=BORDER_LITE, width=2)
        # polyline
        for i in range(len(pts) - 1):
            d.line([pts[i], pts[i + 1]], fill=PURPLE_MID, width=6)
        # dots
        for px, py in pts:
            d.ellipse([(px - 8, py - 8), (px + 8, py + 8)], fill=PURPLE_MID)
        # highlight last (single-day dip) with red ring
        lx, ly = pts[-2]  # yesterday was the dip in our data
        d.ellipse([(lx - 14, ly - 14), (lx + 14, ly + 14)], outline=RED, width=4)
        d.text((x + 28, cy + 305), "Yesterday was a single-day dip. 7-day trend is stable. No action needed.",
               font=F(F_REG, 24), fill=MUTED)

        # Why NOISE card
        cy2 = cy + ch2 + 22
        ch3 = 180
        for i in range(ch3):
            t = i / (ch3 - 1)
            r = int(78  + (111 - 78)  * t); g = int(63  + (94  - 63)  * t); b = int(112 + (150 - 112) * t)
            d.line([(x, cy2 + i), (x + w, cy2 + i)], fill=(r, g, b))
        round_rect(d, (x, cy2, x + w, cy2 + ch3), r=20)
        d.text((x + 28, cy2 + 24), "Why NOISE?", font=F(F_BOLD, 34), fill=WHITE)
        d.text((x + 28, cy2 + 76), "Rule: only a 3+ day anomaly outside your", font=F(F_REG, 26), fill=(255, 255, 255))
        d.text((x + 28, cy2 + 112), "baseline counts as signal. One day doesn't.", font=F(F_REG, 26), fill=(255, 255, 255))

    bottom = make_phone_area(paint)
    final = Image.new("RGB", (W, H), color=BG)
    final.paste(top, (0, 0))
    final.paste(bottom, (0, 760))
    return final

def screenshot_5_onboarding():
    top = draw_marketing_full(
        eyebrow="SignalVeil · Goal Filter",
        lines=[("Pick a goal.",         [(0, 0)]),
               ("The rest is noise.",   [(14, 60)])],
        sub="You see 3–4 metrics that matter for your goal.<br>Everything else is hidden by design.",
        accent_color=GOLD,
    )

    def paint(area, x, y, w):
        d = ImageDraw.Draw(area)
        # Header
        d.text((x, y + 24), "What's your main health goal?", font=F(F_BOLD, 50), fill=BLACK)
        d.text((x, y + 96), "We'll only show the metrics that matter.", font=F(F_REG, 30), fill=MUTED)
        d.text((x, y + 134), "The rest = noise.", font=F(F_REG, 30), fill=MUTED)

        # Goal cards
        cy = y + 200
        goals = [
            ("🏃", "Running",            "HRV, Resting HR, Sleep, Sleep consistency", True),
            ("⚖️", "Weight Loss",         "Weight, Active energy, Sleep",              False),
            ("🧘", "Stress Management",   "HRV, Resting HR, Respiratory rate",         False),
            ("💚", "General Health",      "Sleep, Steps, HRV, Weight",                 False),
        ]
        for emoji, title, sub, selected in goals:
            ch = 150
            if selected:
                for i in range(ch):
                    t = i / (ch - 1)
                    r = int(78  + (111 - 78)  * t); g = int(63  + (94  - 63)  * t); b = int(112 + (150 - 112) * t)
                    d.line([(x, cy + i), (x + w, cy + i)], fill=(r, g, b))
                fg = WHITE; sub_fg = (220, 220, 230)
            else:
                round_rect(d, (x, cy, x + w, cy + ch), r=20, fill=WHITE, outline=BORDER_LITE, width=2)
                fg = BLACK; sub_fg = MUTED
            if selected:
                round_rect(d, (x, cy, x + w, cy + ch), r=20, outline=PURPLE_LITE, width=4)
            d.text((x + 28, cy + 36), emoji, font=F(F_EMOJI, 56), fill=fg)
            d.text((x + 130, cy + 30), title, font=F(F_BOLD, 38), fill=fg)
            d.text((x + 130, cy + 82), sub, font=F(F_REG, 26), fill=sub_fg)
            cy += ch + 14

    bottom = make_phone_area(paint)
    final = Image.new("RGB", (W, H), color=BG)
    final.paste(top, (0, 0))
    final.paste(bottom, (0, 760))
    return final

def screenshot_6_weekly():
    top = draw_marketing_full(
        eyebrow="SignalVeil · Weekly",
        lines=[("This week: we",          [(15, 60)]),
               ("trusted you 5 times.",  [(8, 65)]),
               ("The watch 2.",          [(10, 50)])],
        sub="Conflict Stats show every time the device and your<br>feeling disagreed — and which one we trusted.",
        accent_color=GOLD,
    )

    def paint(area, x, y, w):
        d = ImageDraw.Draw(area)
        # Veil header
        ch = 170
        for i in range(ch):
            t = i / (ch - 1)
            r = int(78  + (111 - 78)  * t); g = int(63  + (94  - 63)  * t); b = int(112 + (150 - 112) * t)
            d.line([(x, y + i), (x + w, y + i)], fill=(r, g, b))
        round_rect(d, (x, y, x + w, y + ch), r=24)
        d.text((x + 28, y + 24), "WEEK 34 · AUG 22 – 28", font=F(F_BOLD, 26), fill=(255, 255, 255))
        d.text((x + 28, y + 70), "Weekly Summary", font=F(F_BOLD, 48), fill=WHITE)
        d.text((x + 28, y + 132), "Conflict arbitrator report", font=F(F_REG, 26), fill=GOLD)

        # Conflict stats card (soft purple)
        cy = y + ch + 26
        ch2 = 180
        for i in range(ch2):
            t = i / (ch2 - 1)
            r = int(240 + (232 - 240) * t); g = int(235 + (223 - 235) * t); b = int(245 + (241 - 245) * t)
            d.line([(x, cy + i), (x + w, cy + i)], fill=(r, g, b))
        round_rect(d, (x, cy, x + w, cy + ch2), r=22, outline=PURPLE_LITE, width=2)
        # Drawn scale icon (no emoji dependency)
        scx, scy, sr = x + 60, cy + 60, 26
        d.line([(scx - sr, scy), (scx + sr, scy)], fill=PURPLE_DARK, width=4)
        d.line([(scx, scy - sr - 8), (scx, scy + 4)], fill=PURPLE_DARK, width=4)
        d.line([(scx - 10, scy + 4), (scx + 10, scy + 4)], fill=PURPLE_DARK, width=4)
        d.rounded_rectangle([(scx - sr, scy + 4), (scx - 8, scy + 20)], radius=2, outline=PURPLE_DARK, width=2)
        d.rounded_rectangle([(scx + 8, scy + 4), (scx + sr, scy + 20)], radius=2, outline=PURPLE_DARK, width=2)
        d.text((x + 120, cy + 36), "Conflict Stats", font=F(F_BOLD, 40), fill=PURPLE_DARK)
        d.text((x + 28, cy + 110), "When your watch disagreed with you,", font=F(F_REG, 26), fill=MUTED)
        d.text((x + 28, cy + 144), "here's who we trusted.", font=F(F_REG, 26), fill=MUTED)

        # Stats rows
        cy += ch2 + 22
        ch3 = 280
        card(d, x, cy, w, ch3, fill=WHITE)
        d.text((x + 28, cy + 28), "Trusted your feeling", font=F(F_BOLD, 36), fill=BLACK)
        d.text((x + w - 130, cy + 24), "5", font=F(F_BOLD_HUGE, 56), fill=GREEN)
        d.line([(x + 28, cy + 90), (x + w - 28, cy + 90)], fill=BORDER_LITE, width=2)

        d.text((x + 28, cy + 112), "Trusted the watch", font=F(F_BOLD, 36), fill=BLACK)
        d.text((x + w - 130, cy + 108), "2", font=F(F_BOLD_HUGE, 56), fill=RED)
        d.line([(x + 28, cy + 178), (x + w - 28, cy + 178)], fill=BORDER_LITE, width=2)

        d.text((x + 28, cy + 200), "Flagged for tracking", font=F(F_BOLD, 36), fill=BLACK)
        d.text((x + w - 130, cy + 196), "1", font=F(F_BOLD_HUGE, 56), fill=MUTED)

        # Why card
        cy2 = cy + ch3 + 20
        ch4 = 180
        card(d, x, cy2, w, ch4, fill=WHITE)
        d.text((x + 28, cy2 + 24), "Why 2 watch-trusts?", font=F(F_BOLD, 32), fill=BLACK)
        words = "Tuesday & Thursday: HRV outside baseline for 3+ days. The data was louder than your feeling.".split(" ")
        line, lines = "", []
        for wd in words:
            if text_w(d, line + " " + wd, F(F_REG, 26))[0] > w - 80:
                lines.append(line.strip()); line = wd
            else:
                line += " " + wd
        if line.strip(): lines.append(line.strip())
        for li, ln in enumerate(lines[:3]):
            d.text((x + 28, cy2 + 76 + li * 36), ln, font=F(F_REG, 26), fill=MUTED)

    bottom = make_phone_area(paint)
    final = Image.new("RGB", (W, H), color=BG)
    final.paste(top, (0, 0))
    final.paste(bottom, (0, 760))
    return final

# ---- Main ----

def main():
    shots = [
        ("01_quiet_mode.png",          screenshot_1_quiet_mode),
        ("02_conflict_arbitrator.png", screenshot_2_conflict),
        ("03_today_noise.png",         screenshot_3_today_noise),
        ("04_verdict_noise.png",       screenshot_4_verdict),
        ("05_onboarding_goal.png",     screenshot_5_onboarding),
        ("06_weekly_conflict.png",     screenshot_6_weekly),
    ]
    for name, fn in shots:
        img = fn()
        path = OUT / name
        img.save(path, optimize=True)
        print(f"[ok] {name}  {path.stat().st_size // 1024} KB  {img.size}")
    print(f"\nDONE — {len(shots)} PNGs in {OUT}")

if __name__ == "__main__":
    main()
