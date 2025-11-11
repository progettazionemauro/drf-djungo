# movies/signals.py
from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
from .models import Film
from .sse import broadcast

@receiver(post_save, sender=Film)
def film_saved(sender, instance, created, **kwargs):
    action = "created" if created else "updated"
    broadcast("films-changed", {"action": action, "id": instance.id})

@receiver(post_delete, sender=Film)
def film_deleted(sender, instance, **kwargs):
    broadcast("films-changed", {"action": "deleted", "id": instance.id if hasattr(instance, "id") else None})
