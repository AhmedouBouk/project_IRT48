from rest_framework import permissions


class IsAdminUser(permissions.BasePermission):
    """
    Permission pour restreindre l'accès aux utilisateurs administrateurs uniquement.
    """
    def has_permission(self, request, view):
        return request.user and request.user.is_authenticated and request.user.is_admin()


class IsOwnerOrAdmin(permissions.BasePermission):
    """
    Permission pour permettre aux propriétaires d'un objet ou aux administrateurs de le modifier.
    """
    def has_object_permission(self, request, view, obj):
        if request.user.is_admin():
            return True
        
        # Instance de Incident
        if hasattr(obj, 'user'):
            return obj.user == request.user
        
        return False