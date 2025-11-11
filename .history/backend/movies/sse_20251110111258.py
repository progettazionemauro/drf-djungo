# backend/movies/sse.py
import json
import queue
import threading
import time
from django.http import StreamingHttpResponse
from django.utils.encoding import force_str

_clients = []
_clients_lock = threading.Lock()
PING_INTERVAL = 15  # sec

def _event_format(event: str = None, data: dict | str | None = None) -> str:
    parts = []
    if event:
        parts.append(f"event: {event}")
    if data is not None:
        payload = data if isinstance(data, str) else json.dumps(data, ensure_ascii=False)
        for line in force_str(payload).splitlines():
            parts.append(f"data: {line}")
    parts.append("")
    return "\n".join(parts) + "\n"

def _stream_generator(client_q: queue.Queue):
    try:
        while True:
            try:
                event = client_q.get(timeout=PING_INTERVAL)
                yield _event_format(**event)
            except queue.Empty:
                # keep-alive
                yield ": ping\n\n"
            finally:
                while not client_q.empty():
                    try:
                        event = client_q.get_nowait()
                        yield _event_format(**event)
                    except queue.Empty:
                        break
    except GeneratorExit:
        pass

def sse_events(request):
    """/api/events/ — stream SSE unico."""
    client_q = queue.Queue()
    with _clients_lock:
        _clients.append(client_q)

    def _remove_client():
        with _clients_lock:
            try:
                _clients.remove(client_q)
            except ValueError:
                pass

    resp = StreamingHttpResponse(_stream_generator(client_q), content_type="text/event-stream")
    resp["Cache-Control"] = "no-cache"
    resp["X-Accel-Buffering"] = "no"
    resp.add_post_render_callback(lambda r: _remove_client())
    return resp

def broadcast(event: str, data: dict | str | None = None):
    """Invia un evento a tutti i client connessi."""
    payload = {"event": event, "data": data}
    with _clients_lock:
        for q in list(_clients):
            try:
                q.put_nowait(payload)
            except queue.Full:
                pass
