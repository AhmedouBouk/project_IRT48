from django.db import models
from django.contrib.auth.models import AbstractUser
from django.utils.translation import gettext_lazy as _


class CustomUser(AbstractUser):
    """
    Modèle utilisateur personnalisé avec champ supplémentaire pour le rôle
    """
    CITIZEN = 'citizen'
    ADMIN = 'admin'
    
    ROLE_CHOICES = [
        (CITIZEN, _('Citizen')),
        (ADMIN, _('Administrator')),
    ]
    
    role = models.CharField(
        max_length=10,
        choices=ROLE_CHOICES,
        default=CITIZEN,
    )
    
    def is_admin(self):
        return self.role == self.ADMIN
    
    def is_citizen(self):
        return self.role == self.CITIZEN

class Incident(models.Model):
    """
    Modèle pour les incidents signalés par les utilisateurs
    """
    FIRE = 'fire'
    ACCIDENT = 'accident'
    FLOOD = 'flood'
    INFRASTRUCTURE = 'infrastructure'
    OTHER = 'other'
    
    TYPE_CHOICES = [
        (FIRE, _('Fire')),
        (ACCIDENT, _('Accident')),
        (FLOOD, _('Flood')),
        (INFRASTRUCTURE, _('Infrastructure Issue')),
        (OTHER, _('Other')),
    ]
    
    NEW = 'new'
    IN_PROGRESS = 'in_progress'
    RESOLVED = 'resolved'
    
    STATUS_CHOICES = [
        (NEW, _('New')),
        (IN_PROGRESS, _('In Progress')),
        (RESOLVED, _('Resolved')),
    ]
    
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name='incidents')
    incident_type = models.CharField(max_length=15, choices=TYPE_CHOICES)
    title = models.CharField(max_length=100)
    description = models.TextField()
    photo = models.ImageField(upload_to='incidents/')
    latitude = models.FloatField()
    longitude = models.FloatField()
    address = models.CharField(max_length=255, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    status = models.CharField(max_length=12, choices=STATUS_CHOICES, default=NEW)
    is_voice_description = models.BooleanField(default=False)
    local_id = models.CharField(max_length=100, blank=True, null=True)  # Pour la synchronisation

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return self.title