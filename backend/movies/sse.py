# movies/sse.py
import json, queue, threading, time
from django.http import StreamingHttpResponse
from django.utils.encoding import force_str

_clients = []
_clients_lock = threading.Lock()
PING_INTERVAL = 15

def _event_format(event=None, data=None) -> str:
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
                ev = client_q.get(timeout=PING_INTERVAL)
                yield _event_format(**ev)
            except queue.Empty:
                yield ": ping\n\n"
            finally:
                while not client_q.empty():
                    try:
                        ev = client_q.get_nowait()
                        yield _event_format(**ev)
                    except queue.Empty:
                        break
    except GeneratorExit:
        pass

def sse_events(request):
    q = queue.Queue()
    with _clients_lock:
        _clients.append(q)

    def _remove():
        with _clients_lock:
            if q in _clients:
                _clients.remove(q)

    resp = StreamingHttpResponse(_stream_generator(q), content_type="text/event-stream")
    resp["Cache-Control"] = "no-cache"
    resp["X-Accel-Buffering"] = "no"
    resp.add_post_render_callback(lambda r: _remove())
    return resp

def broadcast(event: str, data=None):
    payload = {"event": event, "data": data}
    with _clients_lock:
        for q in list(_clients):
            try:
                q.put_nowait(payload)
            except queue.Full:
                pass
