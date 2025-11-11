# backend/movies/signals.py
from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
from .models import Film
from .serializers import FilmSerializer
from .sse import broadcast

@receiver(post_save, sender=Film)
def film_saved(sender, instance, created, **kwargs):
    data = FilmSerializer(instance).data
    if created:
        broadcast("film_created", data)
    else:
        broadcast("film_updated", data)

@receiver(post_delete, sender=Film)
def film_deleted(sender, instance, **kwargs):
    # NB: dopo il delete non hai più l’istanza in DB; manda un payload minimo
    broadcast("film_deleted", {"id": instance.id})
