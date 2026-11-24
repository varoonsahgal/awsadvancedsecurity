"""nimbus manifest-api - parses cargo manifests (YAML). Training app for Lab 3.4."""
import yaml
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.get("/healthz")
def health():
    return "ok"

@app.post("/manifest")
def manifest():
    # BUG ON PURPOSE: yaml.load with the full loader on untrusted input (CVE-2020-14343 territory).
    # The fix is two-fold: upgrade PyYAML AND use yaml.safe_load().
    doc = yaml.load(request.get_data(as_text=True), Loader=yaml.FullLoader)
    return jsonify({"items": len(doc or {})})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
