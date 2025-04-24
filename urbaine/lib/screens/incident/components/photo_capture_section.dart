import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/info_card.dart';

/// A widget for handling photo capture and display with enhanced UI and features
class PhotoCaptureSection extends StatelessWidget {
  /// The currently selected photo file
  final XFile? photoFile;
  
  /// Callback to get an image from a source
  final Function(ImageSource) onGetImage;
  
  /// Callback when the user wants to remove the photo
  final VoidCallback onRemovePhoto;
  
  /// Optional callback to view the photo in full screen
  final Function(XFile)? onViewPhoto;
  
  /// Optional maximum height for the displayed image
  final double imageHeight;
  
  /// Optional loading indicator while image is processing
  final bool isLoading;
  
  /// Optional placeholder text when no image is selected
  final String placeholderText;

  /// Creates an enhanced photo capture section widget
  const PhotoCaptureSection({
    Key? key,
    required this.photoFile,
    required this.onGetImage,
    required this.onRemovePhoto,
    this.onViewPhoto,
    this.imageHeight = 200,
    this.isLoading = false,
    this.placeholderText = 'Ajoutez une photo pour documenter l\'incident',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return InfoCard(
      title: 'Photo de l\'incident',
      icon: Icons.photo_camera_rounded,
      iconColor: AppTheme.primaryColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoading)
            _buildLoadingIndicator(theme)
          else if (photoFile != null)
            _buildPhotoPreview(context, theme)
          else
            _buildEmptyState(context, theme),
            
          if (photoFile == null)
            _buildCaptureButtons(context, theme),
        ],
      ),
    );
  }
  
  /// Builds a loading indicator with animation
  Widget _buildLoadingIndicator(ThemeData theme) {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
          const SizedBox(height: 16),
          Text(
            'Traitement de l\'image...',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Builds the photo preview with edit/delete options
  Widget _buildPhotoPreview(BuildContext context, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          GestureDetector(
            onTap: () {
              if (onViewPhoto != null && photoFile != null) {
                onViewPhoto!(photoFile!);
              }
            },
            child: Hero(
              tag: 'photo-${photoFile?.path ?? "preview"}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                child: kIsWeb
                    ? Image.network(
                        photoFile!.path,
                        width: double.infinity,
                        height: imageHeight,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return _buildErrorPlaceholder(theme);
                        },
                      )
                    : Image.file(
                        File(photoFile!.path),
                        width: double.infinity,
                        height: imageHeight,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return _buildErrorPlaceholder(theme);
                        },
                      ),
              ),
            ),
          ),
          
          // Control buttons overlay
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              children: [
                if (onViewPhoto != null)
                  _buildControlButton(
                    icon: Icons.fullscreen,
                    tooltip: 'Voir en plein écran',
                    onPressed: () {
                      if (photoFile != null) {
                        onViewPhoto!(photoFile!);
                      }
                    },
                  ),
                  
                _buildControlButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Supprimer la photo',
                  onPressed: onRemovePhoto,
                ),
              ],
            ),
          ),
          
          // Replace photo button overlay
          Positioned(
            bottom: 8,
            right: 8,
            child: _buildControlButton(
              icon: Icons.camera_alt,
              tooltip: 'Remplacer la photo',
              onPressed: () => _showSourceSelector(context),
              backgroundColor: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Builds a control button with consistent styling
  Widget _buildControlButton({
    required IconData icon, 
    required String tooltip, 
    required VoidCallback onPressed,
    Color? backgroundColor
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: IconButton(
          tooltip: tooltip,
          icon: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
          constraints: const BoxConstraints(
            minWidth: 36,
            minHeight: 36,
          ),
          padding: const EdgeInsets.all(8),
          onPressed: onPressed,
        ),
      ),
    );
  }
  
  /// Builds the placeholder when there's an error loading the image
  Widget _buildErrorPlaceholder(ThemeData theme) {
    return Container(
      width: double.infinity,
      height: imageHeight,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        border: Border.all(
          color: theme.colorScheme.error.withOpacity(0.5),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            size: 50,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(
            'Impossible de charger l\'image',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Builds the empty state with a message about adding photos
  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_a_photo,
            size: 48,
            color: theme.colorScheme.primary.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              placeholderText,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Builds the camera and gallery buttons
  Widget _buildCaptureButtons(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt, size: 18),
              label: const Text('Appareil photo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                ),
              ),
              onPressed: () => onGetImage(ImageSource.camera),
            ),
          ),
          const SizedBox(width: AppTheme.spacingSmall),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.photo_library, size: 18),
              label: const Text('Galerie'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: theme.colorScheme.onSecondary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                ),
              ),
              onPressed: () => onGetImage(ImageSource.gallery),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Shows a dialog to select image source if context menu is supported
  void _showSourceSelector(BuildContext context) {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Choisir une source',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.camera_alt, color: theme.colorScheme.primary),
              ),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.of(context).pop();
                onGetImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.photo_library, color: theme.colorScheme.secondary),
              ),
              title: const Text('Choisir depuis la galerie'),
              onTap: () {
                Navigator.of(context).pop();
                onGetImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// A fullscreen photo viewer that can be used with PhotoCaptureSection
class FullscreenPhotoViewer extends StatelessWidget {
  final XFile photoFile;
  
  const FullscreenPhotoViewer({
    Key? key,
    required this.photoFile,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.4),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () {
              // Implement share functionality if needed
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fonctionnalité de partage non implémentée')),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Hero(
            tag: 'photo-${photoFile.path}',
            child: kIsWeb
                ? Image.network(
                    photoFile.path,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image,
                      size: 100,
                      color: Colors.white54,
                    ),
                  )
                : Image.file(
                    File(photoFile.path),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image,
                      size: 100,
                      color: Colors.white54,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Example of how to use the enhanced PhotoCaptureSection
///
/// ```dart
/// XFile? _photoFile;
/// bool _isLoadingImage = false;
///
/// // In your build method:
/// PhotoCaptureSection(
///   photoFile: _photoFile,
///   isLoading: _isLoadingImage,
///   onGetImage: (ImageSource source) async {
///     setState(() => _isLoadingImage = true);
///     
///     try {
///       final ImagePicker picker = ImagePicker();
///       final XFile? image = await picker.pickImage(
///         source: source,
///         maxWidth: 1200,
///         imageQuality: 80,
///       );
///       
///       if (image != null) {
///         setState(() => _photoFile = image);
///       }
///     } finally {
///       setState(() => _isLoadingImage = false);
///     }
///   },
///   onRemovePhoto: () {
///     setState(() => _photoFile = null);
///   },
///   onViewPhoto: (XFile photo) {
///     Navigator.of(context).push(
///       MaterialPageRoute(
///         builder: (context) => FullscreenPhotoViewer(photoFile: photo),
///       ),
///     );
///   },
/// )
/// ```