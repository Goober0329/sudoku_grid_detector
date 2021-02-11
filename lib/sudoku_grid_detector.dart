import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:opencv/opencv.dart';
import 'package:path_provider/path_provider.dart';

import 'package:sudoku_grid_detector/image_data.dart';

class SudokuGridDetector {
  // The code in this class is based on the tutorial by Neeramitra Reddy
  // https://medium.com/analytics-vidhya/smart-sudoku-solver-using-opencv-and-tensorflow-in-python3-3c8f42ca80aa

  File _file;
  Uint8List _rawBytes;

  Image _originalImage;
  Image _binaryImage;
  ImageData _binaryImageData;
  Uint8List _res;

  List<List<int>> _sudokuGrid;

  SudokuGridDetector.fromFile(File file) : this._file = file;
  SudokuGridDetector.fromBytes(Uint8List bytes) : this._rawBytes = bytes;

  /// Image widget getters for displaying in Flutter
  Image get originalImage => _originalImage;
  Image get binaryImage => _binaryImage;

  /// sudoku grid getters
  List<List<int>> get sudokuGrid => _sudokuGrid;

  /// main SudokuGridDetector method for finding a Sudoku grid in an image
  Future<bool> detectSudokuGrid() async {
    await _prepareImageData();
    print("image data prepared");

    // TODO image manipulation and grid detection

    return false || true; // ha.ha.
  }

  /// image preparation function that sets many of the class variables and
  /// creates an adaptively thresholded binary image that can be used to
  /// detect the QR codes.
  Future<void> _prepareImageData() async {
    // This function helps convert raw image data into a ui.Image Object
    Future<ui.Image> bytesToImage(Uint8List imgBytes) async {
      ui.Codec codec = await ui.instantiateImageCodec(imgBytes);
      ui.FrameInfo frame = await codec.getNextFrame();
      return frame.image;
    }

    if (_file != null) {
      // image from File
      _originalImage = Image.memory(await _file.readAsBytes());
    } else if (_rawBytes != null) {
      // image from Uint8List
      _file = File('${(await getTemporaryDirectory()).path}/temporary_file');
      await _file.writeAsBytes(_rawBytes.toList());
      print("${_file.path}");
    } else {
      return;
    }

    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      // TODO what are the actual steps that need to be done here?
      // TODO follow the tutorial and kill it.
      // openCV adaptive threshold
      _res = await ImgProc.adaptiveThreshold(
        _file.readAsBytesSync(),
        255,
        ImgProc.adaptiveThreshGaussianC,
        ImgProc.threshBinary,
        51,
        0,
      );
      print("res ${_res == null ? "does" : "doesn't"} equal null");
      _binaryImage = Image.memory((_res));
      print(
          "binaryImage ${_binaryImage == null ? "does" : "doesn't"} equal null");
      _binaryImageData = ImageData(image: await bytesToImage(_res));
      print(
          "binaryImageData ${_binaryImageData == null ? "does" : "doesn't"} equal null");
      await _binaryImageData.imageToByteData();
    } on PlatformException {
      print("some error occurred. possibly OpenCV PlatformException");
    }
  }
}
