from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import CustomUserViewSet, IncidentViewSet

router = DefaultRouter()
router.register(r'users', CustomUserViewSet)
router.register(r'incidents', IncidentViewSet, basename='incident')

urlpatterns = [
    path('', include(router.urls)),
]