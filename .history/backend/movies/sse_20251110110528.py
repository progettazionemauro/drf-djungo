# movies/signals.py
from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
from .models import Film
from .sse import broadcast  # già scritto

def _payload(instance, action):
    return {
        "action": action,
        "id": instance.id,
        "title": instance.title,
    }

@receiver(post_save, sender=Film)
def film_saved(sender, instance, created, **kwargs):
    broadcast("films-changed", _payload(instance, "created" if created else "updated"))

@receiver(post_delete, sender=Film)
def film_deleted(sender, instance, **kwargs):
    # NB: su post_delete instance.id è ancora disponibile
    broadcast("films-changed", _payload(instance, "deleted"))
