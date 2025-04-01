from rest_framework import serializers
from .models import CustomUser, Incident


class CustomUserSerializer(serializers.ModelSerializer):
    class Meta:
        model = CustomUser
        fields = ('id', 'username', 'email', 'first_name', 'last_name', 'role', 'password')
        extra_kwargs = {'password': {'write_only': True}}

    def create(self, validated_data):
        # Ensure role is set to a valid value
        if 'role' not in validated_data or validated_data['role'] not in [CustomUser.CITIZEN, CustomUser.ADMIN]:
            validated_data['role'] = CustomUser.CITIZEN
            
        user = CustomUser.objects.create_user(**validated_data)
        return user


class IncidentSerializer(serializers.ModelSerializer):
    user_username = serializers.ReadOnlyField(source='user.username')
    
    class Meta:
        model = Incident
        fields = '__all__'
        read_only_fields = ('user',)
    
    def create(self, validated_data):
        validated_data['user'] = self.context['request'].user
        return super(IncidentSerializer, self).create(validated_data)
