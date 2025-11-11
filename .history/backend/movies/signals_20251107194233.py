# backend/movies/signals.py
from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
from .models import Film
from .sse import broadcast

EVENT_NAME = "films-changed"

@receiver(post_save, sender=Film)
def on_film_saved(sender, instance, created, **kwargs):
    broadcast(EVENT_NAME, {"id": instance.id, "created": bool(created)})

@receiver(post_delete, sender=Film)
def on_film_deleted(sender, instance, **kwargs):
    broadcast(EVENT_NAME, {"id": instance.id, "deleted": True})
