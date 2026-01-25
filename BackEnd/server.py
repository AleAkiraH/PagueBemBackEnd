"""Simple Flask server to simulate API Gateway for lambda_function.lambda_handler

Endpoints:
- POST /decode  -> accepts JSON {"image": "<base64>"} or raw base64 body

This is used only for local testing within the container. The container will call
lambda_function.lambda_handler(event, None) and return its response.
"""
from __future__ import annotations

import json
from typing import Any

from flask import Flask, request, jsonify

from lambda_function import lambda_handler

app = Flask(__name__)


@app.route("/decode", methods=["POST"])
def decode_endpoint():
    # Try JSON first
    try:
        data = request.get_json(force=False)
    except Exception:
        data = None

    if data and isinstance(data, dict):
        # standard case: JSON body containing {"image": "..."}
        event = {"body": json.dumps(data)}
    else:
        # raw body: treat as base64 string
        raw = request.get_data(as_text=True)
        if not raw:
            return jsonify({"error": "no data provided"}), 400
        event = {"isBase64Encoded": True, "body": raw}

    resp = lambda_handler(event, None)

    # lambda_handler returns a dict with statusCode, headers and body
    status = resp.get("statusCode", 200)
    body = resp.get("body", "{}")
    try:
        parsed = json.loads(body)
        return jsonify(parsed), status
    except Exception:
        return body, status


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
