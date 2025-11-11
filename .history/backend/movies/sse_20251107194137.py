# backend/movies/sse.py
import json
import queue
import threading
import time
from django.http import StreamingHttpResponse
from django.views.decorators.http import condition
from django.utils.encoding import force_str

# Semplice registry di client connessi: una lista di Queue
_clients = []
_clients_lock = threading.Lock()

PING_INTERVAL = 15  # secondi, keep-alive per evitare chiusure proxy

def _event_format(event: str = None, data: dict | str | None = None) -> str:
    """Formatta un evento SSE secondo lo standard."""
    parts = []
    if event:
        parts.append(f"event: {event}")
    if data is not None:
        payload = data if isinstance(data, str) else json.dumps(data, ensure_ascii=False)
        # Spezza su righe per compatibilità SSE
        for line in force_str(payload).splitlines():
            parts.append(f"data: {line}")
    # Terminatore evento
    parts.append("")  # linea vuota
    return "\n".join(parts) + "\n"

def _stream_generator(client_q: queue.Queue):
    """Generatore che invia eventi al client finché resta connesso."""
    last_ping = time.time()
    try:
        while True:
            try:
                # Attendi un evento per max PING_INTERVAL sec
                event = client_q.get(timeout=PING_INTERVAL)
                yield _event_format(**event)
            except queue.Empty:
                # Keep-alive ping (comment line SSE)
                yield ": ping\n\n"
            finally:
                # Evita code non lette che crescono
                while not client_q.empty():
                    try:
                        event = client_q.get_nowait()
                        yield _event_format(**event)
                    except queue.Empty:
                        break
    except GeneratorExit:
        # Connessione chiusa dal client
        pass

def sse_events(request):
    """Endpoint /api/events/ — apre uno stream text/event-stream."""
    client_q = queue.Queue()
    with _clients_lock:
        _clients.append(client_q)

    def _remove_client():
        with _clients_lock:
            try:
                _clients.remove(client_q)
            except ValueError:
                pass

    # Streaming response
    response = StreamingHttpResponse(
        streaming_content=_stream_generator(client_q),
        content_type="text/event-stream",
    )
    # Header importanti per SSE
    response["Cache-Control"] = "no-cache"
    response["X-Accel-Buffering"] = "no"  # per Nginx: disabilita buffering
    # Quando la connessione è chiusa, rimuovi il client
    response.add_post_render_callback(lambda r: _remove_client())
    return response

def broadcast(event: str, data: dict | str | None = None):
    """Invia un evento a tutti i client connessi."""
    payload = {"event": event, "data": data}
    with _clients_lock:
        for q in list(_clients):
            # Non bloccare se la coda del client è piena
            try:
                q.put_nowait(payload)
            except queue.Full:
                # Se un client non consuma, lo “saltiamo”
                pass
