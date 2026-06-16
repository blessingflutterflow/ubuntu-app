import 'dart:html' as html;
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

/// Generates a JPEG thumbnail from a video using HTML5 video + canvas.
/// Matches Kotlin's VideoThumbnailGenerator pattern (frame at ~1 second).
Future<XFile?> generateVideoThumbnail(XFile video) async {
  try {
    final videoUrl = video.path;
    final videoEl = html.VideoElement()
      ..src = videoUrl
      ..muted = true
      ..preload = 'auto'
      ..style.display = 'none';

    html.document.body!.append(videoEl);

    // Wait for metadata so we have dimensions & duration
    await videoEl.onLoadedMetadata.first;

    // Seek to 1 second (or mid-point if video < 1s)
    final seekTime = videoEl.duration > 1.0 ? 1.0 : videoEl.duration / 2;
    videoEl.currentTime = seekTime;

    // Wait for the seek to finish
    await videoEl.onSeeked.first;

    // Draw frame to canvas
    final canvas = html.CanvasElement(
      width: videoEl.videoWidth,
      height: videoEl.videoHeight,
    );
    canvas.context2D.drawImage(videoEl, 0, 0);

    // Cleanup DOM
    videoEl.remove();

    // Export as JPEG blob
    final blob = await canvas.toBlob('image/jpeg', 0.85);
    final reader = html.FileReader();
    reader.readAsArrayBuffer(blob);
    await reader.onLoadEnd.first;

    final bytes = Uint8List.view(reader.result as ByteBuffer);

    // Create a blob URL the XFile can use
    final thumbBlob = html.Blob([bytes], 'image/jpeg');
    final thumbUrl = html.Url.createObjectUrl(thumbBlob);

    return XFile(thumbUrl, name: 'thumbnail.jpg', mimeType: 'image/jpeg');
  } catch (e) {
    // Thumbnail generation is best-effort
    return null;
  }
}
