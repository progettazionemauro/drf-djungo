from rest_framework import viewsets
from .models import Film
from .serializers import FilmSerializer

from rest_framework.permissions import AllowAny
permission_classes = [AllowAny]


class FilmViewSet(viewsets.ModelViewSet):
    queryset = Film.objects.all().order_by('-id')
    serializer_class = FilmSerializer
