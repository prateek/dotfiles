"""Deterministic Anthropic Messages endpoint for the real Claude CLI lane."""
import http.server
import json
import pathlib

RESPONSE = "Fixture answer from the isolated API server."


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def do_GET(self):
        self.send_response(200 if self.path == "/health" else 404)
        self.end_headers()

    def do_POST(self):
        payload = json.loads(self.rfile.read(int(self.headers.get("Content-Length", "0"))))
        if self.path.endswith("/count_tokens"):
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"input_tokens":10}')
            return
        if "/messages" not in self.path:
            self.send_error(404)
            return
        model = payload.get("model", "claude-sonnet-4-6")
        message = {"id": "msg_fixture", "type": "message", "role": "assistant", "model": model,
                   "content": [], "stop_reason": None, "stop_sequence": None,
                   "usage": {"input_tokens": 10, "output_tokens": 0}}
        pathlib.Path("/tmp/llm-request-count").write_text(str(
            int(pathlib.Path("/tmp/llm-request-count").read_text()) + 1
            if pathlib.Path("/tmp/llm-request-count").exists() else 1))
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream" if payload.get("stream") else "application/json")
        self.end_headers()
        if not payload.get("stream"):
            message.update(content=[{"type": "text", "text": RESPONSE}], stop_reason="end_turn")
            self.wfile.write(json.dumps(message).encode())
            return
        events = [
            ("message_start", {"type": "message_start", "message": message}),
            ("content_block_start", {"type": "content_block_start", "index": 0,
                                      "content_block": {"type": "text", "text": ""}}),
            ("content_block_delta", {"type": "content_block_delta", "index": 0,
                                      "delta": {"type": "text_delta", "text": RESPONSE}}),
            ("content_block_stop", {"type": "content_block_stop", "index": 0}),
            ("message_delta", {"type": "message_delta", "delta": {"stop_reason": "end_turn", "stop_sequence": None},
                                "usage": {"output_tokens": 10}}),
            ("message_stop", {"type": "message_stop"}),
        ]
        for event, data in events:
            self.wfile.write(f"event: {event}\ndata: {json.dumps(data)}\n\n".encode())
            self.wfile.flush()


if __name__ == "__main__":
    http.server.ThreadingHTTPServer(("127.0.0.1", 8033), Handler).serve_forever()
