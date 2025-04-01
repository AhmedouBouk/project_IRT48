from rest_framework import viewsets, permissions, status
from rest_framework.response import Response
from rest_framework.decorators import action
from .models import CustomUser, Incident
from .serializers import CustomUserSerializer, IncidentSerializer
from .permissions import IsAdminUser, IsOwnerOrAdmin


class CustomUserViewSet(viewsets.ModelViewSet):
    queryset = CustomUser.objects.all()
    serializer_class = CustomUserSerializer
    
    def get_permissions(self):
        if self.action == 'create':
            permission_classes = [permissions.AllowAny]
        elif self.action == 'me':
            permission_classes = [permissions.IsAuthenticated]
        else:
            permission_classes = [IsAdminUser]
        return [permission() for permission in permission_classes]

    def create(self, request, *args, **kwargs):
        print(f"Request data: {request.data}")
        serializer = self.get_serializer(data=request.data)
        if not serializer.is_valid():
            print(f"Validation errors: {serializer.errors}")
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        serializer.save()
        headers = self.get_success_headers(serializer.data)
        return Response(serializer.data, status=status.HTTP_201_CREATED, headers=headers)

    @action(detail=False, methods=['get'])
    def me(self, request):
        serializer = self.get_serializer(request.user)
        return Response(serializer.data)


class IncidentViewSet(viewsets.ModelViewSet):
    serializer_class = IncidentSerializer
    
    def get_queryset(self):
        user = self.request.user
        if user.is_admin():
            return Incident.objects.all()
        return Incident.objects.filter(user=user)
    
    def get_permissions(self):
        if self.action in ['retrieve', 'update', 'partial_update', 'destroy']:
            permission_classes = [permissions.IsAuthenticated, IsOwnerOrAdmin]
        else:
            permission_classes = [permissions.IsAuthenticated]
        return [permission() for permission in permission_classes]
    
    @action(detail=False, methods=['post'], url_path='sync')
    def sync_incidents(self, request):
        """
        Point de terminaison pour synchroniser les incidents enregistrés en mode hors ligne
        """
        incidents_data = request.data
        
        if not isinstance(incidents_data, list):
            return Response({"error": "Expected a list of incidents"}, status=status.HTTP_400_BAD_REQUEST)
        
        created_incidents = []
        for incident_data in incidents_data:
            local_id = incident_data.get('local_id')
            
            # Vérifier si l'incident existe déjà
            if local_id and Incident.objects.filter(local_id=local_id).exists():
                continue
                
            serializer = self.get_serializer(data=incident_data)
            if serializer.is_valid():
                serializer.save(user=request.user)
                created_incidents.append(serializer.data)
        
        return Response(created_incidents, status=status.HTTP_201_CREATED)