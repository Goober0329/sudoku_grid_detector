import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// [ImageData] is a class that takes a ui.Image and allows the user
/// to access individual pixel color values from the image with the use of the
/// [pixelColorAt] method. Before pixel color values can be retrieved,
/// the [imageToByteData] function must be called to first obtain the image data
class ImageData {
  ui.Image image;
  ByteData _byteData;
  int _width;
  int _height;

  ImageData({@required this.image});

  int get width => _width;
  int get height => _height;

  /// convert ui.Image to ByteData to be used in pixel getting
  /// this method must be called once after class initialization and before
  /// calling [pixelColorAt]
  Future<void> imageToByteData() async {
    if (image == null) {
      print("image was null and couldn't get byteData");
      _byteData = null;
      _width = null;
      _height = null;
    } else {
      print("image wasn't null");
      _width = image.width;
      print("image width: $_width");
      _height = image.height;
      print("image height: $_height");
      _byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      print("byteData retrieved? ${_byteData == null ? "no" : "yes"}");
    }
  }

  /// Pixel coordinates: (0,0) → (width-1, height-1)
  Color pixelColorAt(int x, int y) {
    if (_byteData == null ||
        _width == null ||
        _height == null ||
        x < 0 ||
        x >= _width ||
        y < 0 ||
        y >= _height)
      return null;
    else {
      var byteOffset = 4 * (x + (y * _width));
      return _colorAtByteOffset(byteOffset);
    }
  }

  Color _colorAtByteOffset(int byteOffset) =>
      Color(_rgbaToArgb(_byteData.getUint32(byteOffset)));

  int _rgbaToArgb(int rgbaColor) {
    int a = rgbaColor & 0xFF;
    int rgb = rgbaColor >> 8;
    return rgb + (a << 24);
  }
}
