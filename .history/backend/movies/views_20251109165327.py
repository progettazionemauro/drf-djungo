from rest_framework import viewsets
from rest_framework.permissions import AllowAny

from django.http import StreamingHttpResponse
import json, time

from .models import Film
from .serializers import FilmSerializer


# ===== DRF ViewSet =====
class FilmViewSet(viewsets.ModelViewSet):
    queryset = Film.objects.all().order_by('-id')
    serializer_class = FilmSerializer
    permission_classes = [AllowAny]   # <-- mettila qui (non a livello modulo)


# ===== SSE helpers + endpoint =====
def _sse(event, payload):
    """Formatta un messaggio SSE (Server-Sent Event)."""
    return f"event: {event}\ndata: {json.dumps(payload)}\n\n"

def film_events_sse(request):
    """
    Stream SSE minimale: manda un 'hello' iniziale e un 'ping' ogni 15 secondi.
    Serve solo per verificare che l’endpoint e CORS funzionino.
    """
    def stream():
        # messaggio iniziale per confermare la connessione
        yield _sse("hello", {"status": "connected"})
        # heartbeat periodico
        while True:
            yield _sse("ping", {"t": time.time()})
            time.sleep(15)

    resp = StreamingHttpResponse(stream(), content_type="text/event-stream")
    resp["Cache-Control"] = "no-cache"
    resp["X-Accel-Buffering"] = "no"  # utile se poi metti Nginx
    return resp
