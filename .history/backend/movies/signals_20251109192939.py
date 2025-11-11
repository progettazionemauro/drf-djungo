# backend/movies/signals.py
from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
from .models import Film
from .serializers import FilmSerializer
from .sse import broadcast

@receiver(post_save, sender=Film)
def film_saved(sender, instance: Film, created, **kwargs):
    data = FilmSerializer(instance).data
    if created:
        broadcast('film_created', data)
    else:
        broadcast('film_updated', data)
    broadcast('films-changed', {'id': data.get('id')})

@receiver(post_delete, sender=Film)
def film_deleted(sender, instance: Film, **kwargs):
    broadcast('film_deleted', {'id': instance.id})
    broadcast('films-changed', {'id': instance.id})
