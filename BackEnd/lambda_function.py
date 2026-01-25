"""AWS Lambda handler for decoding QR/barcodes from a base64-encoded image

Expected input (API Gateway POST):
- JSON body with key "image" containing a base64 string (optionally a data URI like "data:image/jpeg;base64,...")
- or body may be the raw base64 string with `isBase64Encoded` set to true

Response: JSON with fields `found` (bool), `results` (list of {type,data}), and `transform` that succeeded.

Notes:
- This uses pyzbar (preferred) with a fallback to OpenCV's QRCodeDetector when available.
- pyzbar requires the native ZBar library to be available in the Lambda environment (use a Lambda Layer or container image).
- For best results you may want to increase Lambda memory/timeout and/or prepackage dependencies as a layer.
"""

from __future__ import annotations

import base64
import json
import io
import logging
from typing import Any, Dict, List, Optional

from PIL import Image, ImageEnhance, ImageOps

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Optional backends
HAS_PYZBAR = False
HAS_CV2 = False
try:
    from pyzbar.pyzbar import decode as zbar_decode
    HAS_PYZBAR = True
except Exception:
    zbar_decode = None

try:
    import cv2
    import numpy as np
    HAS_CV2 = True
except Exception:
    cv2 = None
    np = None


def _clean_b64(b64: str) -> str:
    # Remove data URI prefix if present and whitespace/newlines
    if not isinstance(b64, str):
        raise ValueError("image must be a base64 string")
    if b64.startswith("data:"):
        parts = b64.split(",", 1)
        if len(parts) == 2:
            b64 = parts[1]
    # remove whitespace/newlines
    return "".join(b64.split())


def decode_image_from_base64(b64: str) -> Image.Image:
    b64 = _clean_b64(b64)
    raw = base64.b64decode(b64)
    img = Image.open(io.BytesIO(raw))
    img.load()
    return img


def try_decode_pyzbar(img: Image.Image) -> List[Dict[str, str]]:
    try:
        decoded = zbar_decode(img)
        out = []
        for d in decoded:
            try:
                data_str = d.data.decode("utf-8")
            except Exception:
                data_str = d.data.decode("latin-1", errors="replace")
            out.append({"type": d.type, "data": data_str})
        return out
    except Exception:
        logger.exception("pyzbar decode error")
        return []


def try_decode_cv2(img: Image.Image) -> List[Dict[str, str]]:
    # Convert PIL image to BGR numpy array
    try:
        arr = np.array(img.convert("RGB"))
        bgr = arr[:, :, ::-1].copy()
        detector = cv2.QRCodeDetector()
        out = []
        # Newer OpenCV versions have detectAndDecodeMulti
        if hasattr(detector, "detectAndDecodeMulti"):
            try:
                retval, decoded_info, points, _ = detector.detectAndDecodeMulti(bgr)
            except Exception:
                # signature differences across versions
                decoded_info = []
            if decoded_info is None:
                decoded_info = []
            for info in decoded_info:
                if info:
                    out.append({"type": "QRCODE", "data": info})
        else:
            # fallback to single
            try:
                info, points, _ = detector.detectAndDecode(bgr)
                if info:
                    out.append({"type": "QRCODE", "data": info})
            except Exception:
                pass
        return out
    except Exception:
        logger.exception("cv2 decode error")
        return []


def try_decode(img: Image.Image) -> List[Dict[str, str]]:
    # try pyzbar first, then cv2
    if HAS_PYZBAR:
        res = try_decode_pyzbar(img)
        if res:
            return res
    if HAS_CV2:
        res = try_decode_cv2(img)
        if res:
            return res
    return []


# Preprocessing transforms (same as original QrReader script)
TRANSFORMS = [
    ("orig", lambda im: im),
    ("gray", lambda im: im.convert("L")),
    (
        "gray_resize_x2",
        lambda im: im.convert("L").resize((im.size[0] * 2, im.size[1] * 2), Image.BICUBIC),
    ),
    (
        "gray_resize_x3",
        lambda im: im.convert("L").resize((im.size[0] * 3, im.size[1] * 3), Image.BICUBIC),
    ),
    ("contrast_x2", lambda im: ImageEnhance.Contrast(im.convert("L")).enhance(2.0)),
    ("sharp_x2", lambda im: ImageEnhance.Sharpness(im).enhance(2.0)),
    (
        "contrast_gray_thresh",
        lambda im: ImageEnhance.Contrast(im.convert("L")).enhance(2.0).point(lambda p: 255 if p > 120 else 0),
    ),
    ("binary", lambda im: im.convert("L").point(lambda p: 255 if p > 128 else 0)),
    ("invert", lambda im: ImageOps.invert(im.convert("L"))),
]


def _extract_base64_from_event(event: Any) -> Optional[str]:
    # Accepts API Gateway style event or direct lambda invocation payload
    if not isinstance(event, dict):
        return None

    # case 1: API Gateway with isBase64Encoded true
    if event.get("isBase64Encoded") and event.get("body"):
        return event["body"]

    body = event.get("body")

    IMAGE_KEYS = ("image", "image_base64", "img", "b64")

    def _extract_from_obj(obj, max_unwrap: int = 5) -> Optional[str]:
        """Try to extract a base64 image string from obj, unwrapping JSON/'body' fields.
        Stops after max_unwrap iterations to avoid infinite loops."""
        unwraps = 0
        while unwraps < max_unwrap and obj is not None:
            # If obj is a dict, check direct image keys or follow 'body'
            if isinstance(obj, dict):
                for key in IMAGE_KEYS:
                    if key in obj:
                        logger.info("extracted base64 from dict via key=%s after %d unwrappings", key, unwraps)
                        return obj[key]
                # follow nested body if present
                if "body" in obj:
                    obj = obj["body"]
                    unwraps += 1
                    continue
                return None

            # If obj is a string, try to parse JSON; if not JSON, assume raw base64
            if isinstance(obj, str):
                try:
                    parsed = json.loads(obj)
                    obj = parsed
                    unwraps += 1
                    continue
                except Exception:
                    # not JSON: assume raw base64 string
                    logger.info("extracted raw base64 string after %d unwrappings", unwraps)
                    return obj

            # Other types (lists, numbers...) are not supported
            return None

        # Final attempt if obj ended up as dict after exhausting unwraps
        if isinstance(obj, dict):
            for key in IMAGE_KEYS:
                if key in obj:
                    logger.info("extracted base64 from dict via key=%s after max unwrappings", key)
                    return obj[key]
        return None

    # try extracting from the body first (typical API Gateway -> body string or dict)
    if body is not None:
        # body can be a JSON string or raw base64; _extract_from_obj will handle both
        res = _extract_from_obj(body)
        if res:
            return res

    # direct top-level image key
    for key in ("image", "image_base64", "img", "b64"):
        if key in event:
            return event[key]

    return None


def lambda_handler(event: Any, context: Any) -> Dict[str, Any]:
    # Very small, non-sensitive debug prints to help diagnose event shape differences between direct invoke and API Gateway
    try:
        if isinstance(event, dict):
            try:
                print("DEBUG_EVENT_KEYS:", list(event.keys()))
            except Exception:
                print("DEBUG_EVENT_KEYS: <unlistable>")
            if "body" in event:
                b = event["body"]
                if isinstance(b, str):
                    print(f"DEBUG_BODY: str len={len(b)} prefix={b[:80]!r}")
                else:
                    print(f"DEBUG_BODY: type={type(b)}")
        else:
            print("DEBUG_EVENT_TYPE:", type(event))

        # Lightweight, non-sensitive request-shape logging for debugging
        if isinstance(event, dict):
            try:
                logger.info("incoming event keys=%s", list(event.keys()))
            except Exception:
                logger.info("incoming event (non-listable keys)")
            body_preview = None
            if "body" in event:
                b = event["body"]
                if isinstance(b, str):
                    body_preview = f"string(len={len(b)})"
                else:
                    body_preview = f"type={type(b)}"
            logger.info("body preview=%s", body_preview)

        b64 = _extract_base64_from_event(event)
        if not b64:
            return {
                "statusCode": 400,
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"error": "no base64 image found in request"}),
            }

        img = decode_image_from_base64(b64)
    except Exception as e:
        logger.exception("failed decoding input image")
        return {
            "statusCode": 400,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "failed to decode image", "details": str(e)}),
        }

    w, h = img.size
    logger.info(f"input image size={w}x{h}, mode={img.mode}")

    found = False
    result: List[Dict[str, str]] = []
    used_transform: Optional[str] = None

    for angle in (0, 90, 180, 270):
        for name, fn in TRANSFORMS:
            tname = f"{name}_rot{angle}"
            try:
                img_t = fn(img.rotate(angle, expand=True))
            except Exception:
                logger.exception("transform error for %s", tname)
                continue

            decoded = try_decode(img_t)
            if decoded:
                found = True
                result = decoded
                used_transform = tname
                break
        if found:
            break

    if not found:
        body = {"found": False, "message": "No QR/barcode detected with tried preprocessing steps"}
    else:
        body = {"found": True, "transform": used_transform, "results": result}
        # Convenience field: include top-level `data` matching the first result (or list for multiple)
        try:
            if len(result) == 1:
                body["data"] = result[0].get("data")
            else:
                body["data"] = [r.get("data") for r in result]
        except Exception:
            pass

    return {"statusCode": 200, "headers": {"Content-Type": "application/json"}, "body": json.dumps(body)}


# Simple local test helper (invoked when running this file directly)
if __name__ == "__main__":
    import sys

    sample = "qrcode1.jpeg"
    if len(sys.argv) > 1:
        sample = sys.argv[1]

    try:
        with open(sample, "rb") as f:
            b64 = base64.b64encode(f.read()).decode("ascii")
        # JSON body case (typical API Gateway with application/json)
        event_json_body = {"body": json.dumps({"image": b64})}
        print("json body ->", json.loads(lambda_handler(event_json_body, None)["body"]))

        # Raw base64 case (API Gateway binary body, isBase64Encoded=True)
        event_base64_body = {"isBase64Encoded": True, "body": b64}
        print("raw base64 body ->", json.loads(lambda_handler(event_base64_body, None)["body"]))

        # Double-wrapped body (common when sending saved invoke payload.json directly as request body)
        event_double_wrapped = {"body": json.dumps({"body": json.dumps({"image": b64})})}
        print("double wrapped ->", json.loads(lambda_handler(event_double_wrapped, None)["body"]))
    except Exception as e:
        print("local test failed:", e)
