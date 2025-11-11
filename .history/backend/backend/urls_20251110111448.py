from django.contrib import admin
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from movies.views import FilmViewSet
from movies.sse import sse_events  # <-- QUI

router = DefaultRouter()
router.register(r'films', FilmViewSet)

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/events/', sse_events),  # <-- stream SSE
    path('api/', include(router.urls)),
]
