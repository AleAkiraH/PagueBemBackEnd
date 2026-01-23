import os
import base64
import io
from pyzbar.pyzbar import decode
from PIL import Image, ImageEnhance, ImageOps

ROOT = os.path.dirname(__file__)
files = [
    os.path.join(ROOT, "qrcode1.jpeg"),
    os.path.join(ROOT, "qrcode2.jpeg"),
    os.path.join(ROOT, "qrcode3.jpeg"),
]

def procQrBarCod(base64_str):
    """Decode a base64-encoded image and try to read any QR/barcodes in it.

    Returns a list of dicts with keys 'type' and 'data' when codes are found,
    None when no codes are found, or a dict with an 'error' key on failure.
    """
    try:
        raw = base64.b64decode(base64_str)
        img = Image.open(io.BytesIO(raw))
        decoded = decode(img)
        if not decoded:
            return None
        out = []
        for d in decoded:
            try:
                data_str = d.data.decode('utf-8')
            except Exception:
                data_str = d.data.decode('latin-1', errors='replace')
            out.append({'type': d.type, 'data': data_str})
        return out
    except Exception as e:
        return {'error': str(e)}
    
def try_decode(img):
    try:
        decoded = decode(img)
        if decoded:
            return decoded
    except Exception as e:
        print("    decode error:", e)
    return None

for path in files:
    print("File:", path)
    if not os.path.exists(path):
        print("  -> not found")
        print("----------------------------------------")
        continue

    try:
        orig = Image.open(path)
    except Exception as e:
        print("  -> error opening image:", e)
        print("----------------------------------------")
        continue

    w, h = orig.size
    print(f"  size={w}x{h}, mode={orig.mode}")

    found = False

    transforms = [
        ("orig", lambda im: im),
        ("gray", lambda im: im.convert('L')),
        ("gray_resize_x2", lambda im: im.convert('L').resize((im.size[0]*2, im.size[1]*2), Image.BICUBIC)),
        ("gray_resize_x3", lambda im: im.convert('L').resize((im.size[0]*3, im.size[1]*3), Image.BICUBIC)),
        ("contrast_x2", lambda im: ImageEnhance.Contrast(im.convert('L')).enhance(2.0)),
        ("sharp_x2", lambda im: ImageEnhance.Sharpness(im).enhance(2.0)),
        ("contrast_gray_thresh", lambda im: ImageEnhance.Contrast(im.convert('L')).enhance(2.0).point(lambda p: 255 if p>120 else 0)),
        ("binary", lambda im: im.convert('L').point(lambda p: 255 if p>128 else 0)),
        ("invert", lambda im: ImageOps.invert(im.convert('L'))),
    ]

    for angle in [0, 90, 180, 270]:
        for name, fn in transforms:
            tname = f"{name}_rot{angle}"
            try:
                img_t = fn(orig.rotate(angle, expand=True))
            except Exception as e:
                print(f"    transform {tname} error: {e}")
                continue

            decoded = try_decode(img_t)
            if decoded:
                print(f"  Found with: {tname}")
                for i, d in enumerate(decoded, start=1):
                    data_bytes = d.data
                    try:
                        data_str = data_bytes.decode('utf-8')
                    except:
                        data_str = data_bytes.decode('latin-1', errors='replace')
                    print(f"    pyzbar #{i}: type={d.type}, data={data_str}")

                try:
                    buf = io.BytesIO()
                    img_t.save(buf, format='JPEG')
                    b64 = base64.b64encode(buf.getvalue()).decode('utf8')
                    proc_result = procQrBarCod(b64)
                    print("    procQrBarCod ->", proc_result)
                except Exception as e:
                    print("    procQrBarCod error:", e)

                found = True
                break
        if found:
            break

    if not found:
        print("  No QR code detected with the tried free preprocessing steps")
    print("----------------------------------------")
