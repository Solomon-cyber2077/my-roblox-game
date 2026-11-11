"""Classic-style face decals for the six hall passengers, in the game's uneasy tone: dark sunken
sockets, small fixed pupils, flat or downturned mouths, no smiles. Drawn from scratch (no references
traced). Writes <id>-face.png (512x512, transparent) to assets/crew-clothing/passengers-r6/.
Run: python tools/crew-clothing/passenger_faces.py"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parents[2] / 'assets/crew-clothing/passengers-r6'
S = 512
INK = (24, 18, 16, 255)

def socket(layer, cx, cy, w, h, alpha):
    d = ImageDraw.Draw(layer)
    d.ellipse((cx - w, cy - h, cx + w, cy + h), fill=(40, 26, 24, alpha))

def face(name, eye_y=230, eye_dx=62, eye_r=11, sock=(40, 30, 120), mouth='flat', mouth_y=330,
         mouth_w=46, brow=None, closed=False, lines=False):
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    # sunken sockets: a soft dark wash around each eye
    shade = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    for sx in (-1, 1):
        socket(shade, S // 2 + sx * eye_dx, eye_y + 4, sock[0], sock[1], sock[2])
    img = Image.alpha_composite(img, shade.filter(ImageFilter.GaussianBlur(14)))
    d = ImageDraw.Draw(img)
    for sx in (-1, 1):
        cx = S // 2 + sx * eye_dx
        if closed:  # lids down, a thin curve
            d.arc((cx - 24, eye_y - 18, cx + 24, eye_y + 8), 20, 160, fill=INK, width=6)
        else:
            d.ellipse((cx - eye_r, eye_y - eye_r - 3, cx + eye_r, eye_y + eye_r + 3), fill=INK)
            d.ellipse((cx - 3 + sx * 2, eye_y - eye_r + 1, cx + 2 + sx * 2, eye_y - eye_r + 6), fill=(210, 200, 190, 160))
        if brow:
            tilt = brow * sx
            d.line((cx - 26, eye_y - 34 - tilt, cx + 26, eye_y - 34 + tilt), fill=INK, width=6)
        if lines:  # tired lines under the eyes
            d.arc((cx - 22, eye_y + 6, cx + 22, eye_y + 30), 20, 160, fill=(40, 28, 26, 150), width=3)
    cx = S // 2
    if mouth == 'flat':
        d.line((cx - mouth_w, mouth_y, cx + mouth_w, mouth_y), fill=INK, width=7)
    elif mouth == 'down':
        d.arc((cx - mouth_w, mouth_y, cx + mouth_w, mouth_y + 40), 200, 340, fill=INK, width=7)
    elif mouth == 'open':  # a small dark o, as if mid-word and stopped
        d.ellipse((cx - 13, mouth_y - 16, cx + 13, mouth_y + 18), fill=INK)
    elif mouth == 'thin':
        d.line((cx - mouth_w, mouth_y + 4, cx - 6, mouth_y), fill=INK, width=5)
        d.line((cx - 6, mouth_y, cx + mouth_w, mouth_y + 6), fill=INK, width=5)
    img.save(OUT / f'{name}-face.png')

OUT.mkdir(parents=True, exist_ok=True)
face('clerk', mouth='thin', brow=4, lines=True)
face('mother', eye_r=10, mouth='down', mouth_w=34, brow=-5)
face('gentleman', eye_r=8, mouth='flat', mouth_w=40, brow=6, lines=True)
face('porter', eye_r=12, mouth='flat', mouth_w=50, sock=(44, 32, 140))
face('widow', closed=True, mouth='down', mouth_w=30, sock=(46, 34, 150), lines=True)
face('newsboy', eye_r=14, eye_dx=58, mouth='open', sock=(36, 30, 100))
