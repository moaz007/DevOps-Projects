from flask import Flask, jsonify

app = Flask(__name__)

@app.route("/health")
def health():
    return jsonify(status="ok"), 200

@app.route("/")
def index():
    return "Hello from Project 2!", 200

if __name__ == "__main__":
    # Bind to 0.0.0.0 so Docker can expose it
    app.run(host="0.0.0.0", port=5000)
