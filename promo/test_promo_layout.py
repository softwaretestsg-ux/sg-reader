import os
import math
from PIL import Image, ImageDraw, ImageFont

OUTPUT_DIR = "/Users/nalin/.gemini/antigravity/scratch/sg_reader/promo"
WIDTH = 1080
HEIGHT = 1920

# Fonts
FONT_DIR = "/System/Library/Fonts/Supplemental"
font_title = ImageFont.truetype(f"{FONT_DIR}/Arial Bold.ttf", 46)
font_h1 = ImageFont.truetype(f"{FONT_DIR}/Arial Bold.ttf", 38)
font_h2 = ImageFont.truetype(f"{FONT_DIR}/Arial Bold.ttf", 30)
font_body_bold = ImageFont.truetype(f"{FONT_DIR}/Arial Bold.ttf", 25)
font_body = ImageFont.truetype(f"{FONT_DIR}/Arial.ttf", 25)
font_caption = ImageFont.truetype(f"{FONT_DIR}/Arial.ttf", 21)
font_badge = ImageFont.truetype(f"{FONT_DIR}/Arial Bold.ttf", 22)

# Logo
LOGO_PATH = "/Users/nalin/.gemini/antigravity/scratch/sg_reader/assets/images/logo-sg.webp"
logo_img = None
if os.path.exists(LOGO_PATH):
    try:
        logo_img = Image.open(LOGO_PATH).convert("RGBA")
        logo_img = logo_img.resize((320, 138), Image.Resampling.LANCZOS)
    except Exception as e:
        print("Logo load error:", e)

# Colors
BG_DARK = (23, 19, 16)
SURFACE = (31, 25, 19)
SURFACE_CARD = (36, 29, 23)
ACCENT_TERRA = (221, 139, 83)      # #DD8B53
ACCENT_DEEP = (176, 74, 36)        # #B04A24
TEXT_LIGHT = (242, 236, 225)       # #F2ECE1
TEXT_MUTED = (168, 159, 145)       # #A89F91
BORDER = (54, 42, 31)
RED_ACCENT = (229, 83, 75)
GREEN_ACCENT = (76, 175, 80)
BLUE_ACCENT = (74, 126, 187)

def wrap_text(draw, text, font, max_width):
    """Splits text into multiple lines that strictly fit within max_width."""
    words = text.split()
    if not words:
        return []
    lines = []
    current_line = []
    for word in words:
        test_line = ' '.join(current_line + [word])
        bbox = draw.textbbox((0, 0), test_line, font=font)
        w = bbox[2] - bbox[0]
        if w <= max_width:
            current_line.append(word)
        else:
            if current_line:
                lines.append(' '.join(current_line))
                current_line = [word]
            else:
                lines.append(word)
                current_line = []
    if current_line:
        lines.append(' '.join(current_line))
    return lines

def draw_header(draw):
    draw.rectangle([(0, 0), (WIDTH, 130)], fill=SURFACE)
    draw.line([(0, 130), (WIDTH, 130)], fill=BORDER, width=2)
    # Header badge
    draw.rounded_rectangle([(50, 42), (280, 92)], radius=10, fill=(46, 34, 24), outline=ACCENT_DEEP, width=2)
    draw.text((165, 67), "100% OFFLINE SUITE", fill=ACCENT_TERRA, font=font_badge, anchor="mm")
    # Header right text
    draw.text((WIDTH - 50, 67), "www.socialgoogol.com", fill=TEXT_MUTED, font=font_body, anchor="rm")

def draw_footer(draw, progress=0.0):
    draw.rectangle([(0, HEIGHT - 160), (WIDTH, HEIGHT)], fill=SURFACE)
    draw.line([(0, HEIGHT - 160), (WIDTH, HEIGHT - 160)], fill=BORDER, width=2)
    # Helpline & Tagline
    draw.text((WIDTH // 2, HEIGHT - 118), "Helpline: #8126210003 • +91 81262 10003", fill=TEXT_LIGHT, font=font_h2, anchor="mm")
    draw.text((WIDTH // 2, HEIGHT - 68), "Secure to Grow - सुरक्षा से ग्रोथ तक", fill=ACCENT_TERRA, font=font_h2, anchor="mm")
    # Progress Bar
    draw.rectangle([(0, HEIGHT - 6), (int(WIDTH * progress), HEIGHT)], fill=ACCENT_TERRA)

def render_scene_1(t=0.5):
    im = Image.new("RGB", (WIDTH, HEIGHT), BG_DARK)
    draw = ImageDraw.Draw(im)
    draw_header(draw)
    draw_footer(draw, 0.1)

    # Card 1: Problem Card (Strictly within X: 60 to 1020, w=960)
    card1_top = 220
    card1_bot = 620
    draw.rounded_rectangle([(60, card1_top), (WIDTH - 60, card1_bot)], radius=24, fill=(40, 24, 24), outline=RED_ACCENT, width=3)
    
    draw.text((WIDTH // 2, card1_top + 55), "⚠️  PROBLEMS WITH MOST DOCUMENT APPS", fill=RED_ACCENT, font=font_h1, anchor="mm")
    draw.line([(100, card1_top + 95), (WIDTH - 100, card1_top + 95)], fill=(80, 36, 36), width=1)

    problems = [
        "• Bombard you with distracting full-screen popup ads",
        "• Trap basic features behind expensive monthly subscriptions",
        "• Secretly upload your private documents to external servers",
    ]
    py = card1_top + 130
    for prob in problems:
        lines = wrap_text(draw, prob, font_body, 880)
        for line in lines:
            draw.text((95, py), line, fill=TEXT_LIGHT, font=font_body)
            py += 36
        py += 14

    # Card 2: Solution Promise (Strictly within X: 60 to 1020)
    card2_top = 670
    card2_bot = 1120
    draw.rounded_rectangle([(60, card2_top), (WIDTH - 60, card2_bot)], radius=24, fill=SURFACE_CARD, outline=ACCENT_TERRA, width=3)

    draw.text((WIDTH // 2, card2_top + 70), "YOUR CONFIDENTIAL FILES", fill=TEXT_LIGHT, font=font_title, anchor="mm")
    draw.text((WIDTH // 2, card2_top + 135), "DESERVE 100% PRIVACY.", fill=ACCENT_TERRA, font=font_title, anchor="mm")
    draw.line([(120, card2_top + 190), (WIDTH - 120, card2_top + 190)], fill=BORDER, width=2)

    pillars = [
        "🔒  Zero Cloud Uploads: Files never leave your phone",
        "🛡️  Air-Gapped Security: Completely offline sandbox",
        "🚫  Zero Advertisements: Clean, distraction-free interface",
    ]
    py = card2_top + 225
    for pil in pillars:
        draw.text((WIDTH // 2, py), pil, fill=TEXT_MUTED, font=font_h2, anchor="mm")
        py += 60

    # Call to Action Teaser Button
    btn_top = 1190
    btn_bot = 1310
    draw.rounded_rectangle([(WIDTH // 2 - 340, btn_top), (WIDTH // 2 + 340, btn_bot)], radius=20, fill=ACCENT_DEEP, outline=ACCENT_TERRA, width=2)
    draw.text((WIDTH // 2, (btn_top + btn_bot) // 2), "INTRODUCING THE FREE SOLUTION ⬇️", fill=(255, 255, 255), font=font_h1, anchor="mm")

    return im

def render_scene_2(t=0.5):
    im = Image.new("RGB", (WIDTH, HEIGHT), BG_DARK)
    draw = ImageDraw.Draw(im)
    draw_header(draw)
    draw_footer(draw, 0.3)

    # Logo Card (Centered)
    draw.rounded_rectangle([(WIDTH // 2 - 200, 180), (WIDTH // 2 + 200, 350)], radius=24, fill=SURFACE_CARD, outline=ACCENT_TERRA, width=2)
    if logo_img:
        im.paste(logo_img, (WIDTH // 2 - 160, 195), logo_img)

    draw.text((WIDTH // 2, 400), "Social Googol's", fill=TEXT_MUTED, font=font_h2, anchor="mm")
    draw.text((WIDTH // 2, 460), "SG READER", fill=TEXT_LIGHT, font=font_title, anchor="mm")

    # Bilingual Tagline Ribbon
    draw.rounded_rectangle([(140, 520), (WIDTH - 140, 590)], radius=16, fill=SURFACE, outline=BORDER, width=2)
    draw.text((WIDTH // 2, 555), "Secure to Grow - सुरक्षा से ग्रोथ तक", fill=ACCENT_TERRA, font=font_h2, anchor="mm")

    # 3 Structured Pillar Cards (width=960)
    pillars = [
        ("🔒 100% Offline Sandbox", "Zero external network calls. All files processed locally in memory.", GREEN_ACCENT),
        ("🛡️ Biometric & PIN Lock", "Hardware fingerprint/PIN lock keeps sensitive documents protected.", ACCENT_TERRA),
        ("⚡ High-Speed Performance", "Instant cold launch under 0.8s on any Android device.", BLUE_ACCENT),
    ]

    card_y = 630
    for title, desc, col in pillars:
        draw.rounded_rectangle([(60, card_y), (WIDTH - 60, card_y + 160)], radius=18, fill=SURFACE_CARD, outline=col, width=2)
        draw.text((100, card_y + 40), title, fill=col, font=font_h1)
        lines = wrap_text(draw, desc, font_body, 860)
        ly = card_y + 90
        for line in lines:
            draw.text((100, ly), line, fill=TEXT_LIGHT, font=font_body)
            ly += 32
        card_y += 185

    # Big Green Badge
    badge_top = card_y + 20
    draw.rounded_rectangle([(80, badge_top), (WIDTH - 80, badge_top + 100)], radius=20, fill=(30, 48, 30), outline=GREEN_ACCENT, width=2)
    draw.text((WIDTH // 2, badge_top + 50), "✅  100% FREE FOREVER • ZERO SUBSCRIPTION", fill=GREEN_ACCENT, font=font_h1, anchor="mm")

    return im

def render_scene_3(t=0.5):
    im = Image.new("RGB", (WIDTH, HEIGHT), BG_DARK)
    draw = ImageDraw.Draw(im)
    draw_header(draw)
    draw_footer(draw, 0.5)

    draw.text((WIDTH // 2, 190), "ALL YOUR DOCUMENTS.", fill=TEXT_LIGHT, font=font_title, anchor="mm")
    draw.text((WIDTH // 2, 250), "ONE POWERFUL OFFLINE SUITE.", fill=ACCENT_TERRA, font=font_h1, anchor="mm")

    # 4 Document Cards (Strictly within X: 60 to 1020, w=960)
    docs = [
        ("📕 PDF DOCUMENT", "Continuous Page Layout • In-Place Note Stamps • Offline Sharing", RED_ACCENT, (42, 26, 26)),
        ("📊 EXCEL SPREADSHEET", "Full XLSX, XLS & CSV • Cell Formula Bar • Add Rows/Cols • Direct Save", GREEN_ACCENT, (24, 42, 24)),
        ("📝 WORD PROCESSOR", "Full DOCX WYSIWYG Editing • Rich Toolbar • Add Lines • Full Page Flow", BLUE_ACCENT, (24, 34, 48)),
        ("📽️ POWERPOINT SLIDES", "Smooth Presentation Viewer • Slide-by-Slide Review & Offline Deck", ACCENT_TERRA, (42, 32, 24)),
    ]

    card_y = 310
    for title, desc, border_col, fill_col in docs:
        draw.rounded_rectangle([(60, card_y), (WIDTH - 60, card_y + 185)], radius=18, fill=fill_col, outline=border_col, width=2)
        draw.text((100, card_y + 40), title, fill=border_col, font=font_h1)
        lines = wrap_text(draw, desc, font_body, 840)
        ly = card_y + 92
        for line in lines:
            draw.text((100, ly), line, fill=TEXT_LIGHT, font=font_body)
            ly += 32
        # Checkmark
        draw.text((WIDTH - 110, card_y + 60), "✓", fill=border_col, font=font_title)
        card_y += 210

    # Bottom summary box
    draw.rounded_rectangle([(80, 1190), (WIDTH - 80, 1290)], radius=20, fill=SURFACE_CARD, outline=ACCENT_TERRA, width=2)
    draw.text((WIDTH // 2, 1240), "READ   •   EDIT   •   SAVE   •   SHARE", fill=ACCENT_TERRA, font=font_h1, anchor="mm")

    draw.text((WIDTH // 2, 1340), "Auto-detects files shared via WhatsApp & File Manager!", fill=TEXT_LIGHT, font=font_h2, anchor="mm")
    return im

def render_scene_4(t=0.5):
    im = Image.new("RGB", (WIDTH, HEIGHT), BG_DARK)
    draw = ImageDraw.Draw(im)
    draw_header(draw)
    draw_footer(draw, 0.7)

    draw.text((WIDTH // 2, 190), "IN-BUILT DOCUMENT SCANNER", fill=ACCENT_TERRA, font=font_title, anchor="mm")
    draw.text((WIDTH // 2, 245), "Camera Scan • Auto-Refine • Save Any Format", fill=TEXT_LIGHT, font=font_h2, anchor="mm")

    # Scanner Viewfinder Box (Centered, w=760, h=400)
    box_x1 = (WIDTH - 760) // 2
    box_x2 = box_x1 + 760
    box_y1 = 290
    box_y2 = 680
    draw.rounded_rectangle([(box_x1, box_y1), (box_x2, box_y2)], radius=18, fill=(255, 255, 255), outline=ACCENT_DEEP, width=3)
    # Simulated document lines
    draw.rectangle([(box_x1 + 40, box_y1 + 40), (box_x2 - 40, box_y1 + 70)], fill=(40, 40, 40))
    for ly in range(box_y1 + 105, box_y2 - 40, 32):
        draw.rectangle([(box_x1 + 40, ly), (box_x2 - 40, ly + 12)], fill=(200, 200, 200))

    # Scanner Laser Line
    laser_y = box_y1 + int(t * 370)
    draw.line([(box_x1, laser_y), (box_x2, laser_y)], fill=GREEN_ACCENT, width=4)
    draw.text((WIDTH // 2, laser_y - 20), "🪄 AI ENHANCING DOCUMENT CONTOURS...", fill=GREEN_ACCENT, font=font_body_bold, anchor="mm")

    # Filter Chips (Row 1: 3 chips, Row 2: 2 chips)
    chips_r1 = ["🪄 Auto Refine", "📄 Crisp B&W", "🔘 Grayscale"]
    cx = 60
    cy = 720
    cw = 300
    for chip in chips_r1:
        draw.rounded_rectangle([(cx, cy), (cx + cw, cy + 65)], radius=14, fill=SURFACE_CARD, outline=ACCENT_TERRA, width=2)
        draw.text((cx + cw // 2, cy + 32), chip, fill=ACCENT_TERRA, font=font_body_bold, anchor="mm")
        cx += cw + 30

    chips_r2 = ["🎨 Enhanced Color", "🔄 90° Rotate"]
    cx = (WIDTH - (2 * 360 + 30)) // 2
    cy = 805
    cw = 360
    for chip in chips_r2:
        draw.rounded_rectangle([(cx, cy), (cx + cw, cy + 65)], radius=14, fill=SURFACE_CARD, outline=ACCENT_TERRA, width=2)
        draw.text((cx + cw // 2, cy + 32), chip, fill=ACCENT_TERRA, font=font_body_bold, anchor="mm")
        cx += cw + 30

    # Multi-Format Export Card (width=960, top=900, bot=1360)
    draw.rounded_rectangle([(60, 900), (WIDTH - 60, 1360)], radius=24, fill=SURFACE_CARD, outline=GREEN_ACCENT, width=2)
    draw.text((WIDTH // 2, 945), "EXPORT INTO ANY FORMAT:", fill=GREEN_ACCENT, font=font_h1, anchor="mm")
    draw.line([(100, 985), (WIDTH - 100, 985)], fill=BORDER, width=2)

    formats = [
        ("📕 PDF Document (.pdf)", "Multi-page standard A4 document layout"),
        ("📘 Word Document (.docx)", "OpenXML with embedded scan pages"),
        ("🖼️ High-Res Images (.jpg)", "Clean enhanced individual image capture"),
        ("🗂️ ZIP Package (.zip)", "Archived scan bundle + manifest text"),
    ]
    fy = 1015
    for fmt_title, fmt_desc in formats:
        draw.text((100, fy), fmt_title, fill=TEXT_LIGHT, font=font_h2)
        draw.text((100, fy + 38), fmt_desc, fill=TEXT_MUTED, font=font_caption)
        fy += 80

    return im

def render_scene_5(t=0.5):
    im = Image.new("RGB", (WIDTH, HEIGHT), BG_DARK)
    draw = ImageDraw.Draw(im)
    draw_header(draw)
    draw_footer(draw, 0.95)

    # Logo
    if logo_img:
        draw.rounded_rectangle([(WIDTH // 2 - 180, 180), (WIDTH // 2 + 180, 330)], radius=20, fill=SURFACE_CARD, outline=ACCENT_TERRA, width=2)
        im.paste(logo_img, (WIDTH // 2 - 160, 195), logo_img)

    draw.text((WIDTH // 2, 380), "YOU ARE INVITED TO TEST", fill=TEXT_LIGHT, font=font_h1, anchor="mm")
    draw.text((WIDTH // 2, 440), "SOCIAL GOOGOL SG READER", fill=ACCENT_TERRA, font=font_title, anchor="mm")

    # Big 100% Free Box (w=960)
    free_top = 490
    free_bot = 620
    draw.rounded_rectangle([(60, free_top), (WIDTH - 60, free_bot)], radius=20, fill=(28, 48, 28), outline=GREEN_ACCENT, width=3)
    draw.text((WIDTH // 2, free_top + 45), "🎉  100% FREE FOREVER • ZERO ADS", fill=GREEN_ACCENT, font=font_title, anchor="mm")
    draw.text((WIDTH // 2, free_top + 95), "Air-Gapped Privacy • Enterprise Document Power", fill=TEXT_LIGHT, font=font_h2, anchor="mm")

    # Checklist (w=960, top=650, bot=1080)
    draw.rounded_rectangle([(60, 650), (WIDTH - 60, 1080)], radius=20, fill=SURFACE_CARD, outline=BORDER, width=2)
    draw.text((WIDTH // 2, 690), "FEATURE HIGHLIGHTS", fill=ACCENT_TERRA, font=font_h2, anchor="mm")
    draw.line([(100, 725), (WIDTH - 100, 725)], fill=BORDER, width=1)

    checklist = [
        "✓ Read & Edit PDF, Excel (XLSX/XLS), Word (DOCX) & PPT",
        "✓ Built-in Document Scanner with AI Auto-Refining Filters",
        "✓ Multi-Format Export: Save as PDF, Word, Images or ZIP",
        "✓ 1-Tap 'Clear All' Recent Documents & Swipe-to-Dismiss",
        "✓ Hardware Fingerprint / PIN Biometric Security Lock",
    ]
    cy = 750
    for item in checklist:
        draw.text((100, cy), item, fill=TEXT_LIGHT, font=font_body)
        cy += 60

    # Big Download Box (w=960, top=1110, bot=1380)
    dl_top = 1110
    dl_bot = 1380
    draw.rounded_rectangle([(60, dl_top), (WIDTH - 60, dl_bot)], radius=24, fill=ACCENT_DEEP, outline=ACCENT_TERRA, width=3)
    draw.text((WIDTH // 2, dl_top + 55), "DOWNLOAD OFFICIAL APK NOW!", fill=(255, 255, 255), font=font_title, anchor="mm")
    draw.text((WIDTH // 2, dl_top + 130), "Website: www.socialgoogol.com", fill=TEXT_LIGHT, font=font_h1, anchor="mm")
    draw.text((WIDTH // 2, dl_top + 200), "Helpline: +91 81262 10003 (#8126210003)", fill=(255, 255, 255), font=font_h2, anchor="mm")

    return im

def test_static_frames():
    os.makedirs(f"{OUTPUT_DIR}/test_frames", exist_ok=True)
    render_scene_1().save(f"{OUTPUT_DIR}/test_frames/scene_1.jpg", quality=95)
    render_scene_2().save(f"{OUTPUT_DIR}/test_frames/scene_2.jpg", quality=95)
    render_scene_3().save(f"{OUTPUT_DIR}/test_frames/scene_3.jpg", quality=95)
    render_scene_4().save(f"{OUTPUT_DIR}/test_frames/scene_4.jpg", quality=95)
    render_scene_5().save(f"{OUTPUT_DIR}/test_frames/scene_5.jpg", quality=95)
    print("Static test frames generated successfully in promo/test_frames/")

if __name__ == "__main__":
    test_static_frames()
