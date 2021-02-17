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

  String _assetName;
  File _file;
  Uint8List _rawBytes;

  Image _originalImage;
  Image _binaryImage;
  ImageData _binaryImageData;
  Uint8List _res;

  List<List<int>> _sudokuGrid;

  SudokuGridDetector.fromAsset(String assetName) : this._assetName = assetName;
  SudokuGridDetector.fromFile(File file) : this._file = file;
  SudokuGridDetector.fromBytes(Uint8List bytes) : this._rawBytes = bytes;

  List<Image> _stepImages = [];

  /// Image widget getters for displaying in Flutter
  Image get originalImage => _originalImage;
  Image get binaryImage => _binaryImage;
  List<Image> get stepImages => _stepImages; // TODO remove

  /// sudoku grid getters
  List<List<int>> get sudokuGrid => _sudokuGrid;

  /// main SudokuGridDetector method for finding a Sudoku grid in an image
  Future<bool> detectSudokuGrid() async {
    bool allAccordingToPlan;

    // use OpenCV to prepare the image for grid detection
    allAccordingToPlan = await _prepareImageData();
    if (!allAccordingToPlan) return false;

    // detect the grid, perform a matrix transform to show just the grid
    allAccordingToPlan = _detectAndCropGrid();
    if (!allAccordingToPlan) return false;

    // TODO image manipulation and grid detection

    return allAccordingToPlan; // ha. ha.
  }

  /// image preparation function that sets many of the class variables and
  /// creates an adaptively thresholded binary image that can be used to
  /// detect the Sudoku grids.
  Future<bool> _prepareImageData() async {
    // This function helps convert raw image data into a ui.Image Object
    Future<ui.Image> bytesToImage(Uint8List imgBytes) async {
      ui.Codec codec = await ui.instantiateImageCodec(imgBytes);
      ui.FrameInfo frame = await codec.getNextFrame();
      return frame.image;
    }

    // this function gets a file from an asset
    Future<File> getImageFileFromAssets(String path) async {
      final byteData = await rootBundle.load('assets/$path');
      final file = File('${(await getTemporaryDirectory()).path}/$path');
      await file.writeAsBytes(
        byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
      );
      return file;
    }

    if (_assetName != null) {
      // image from asset name
      _file = await getImageFileFromAssets(_assetName);
      _originalImage = Image.file(_file);
    } else if (_file != null) {
      // image from File
      _originalImage = Image.memory(await _file.readAsBytes());
    } else if (_rawBytes != null) {
      // image from Uint8List
      _file = File('${(await getTemporaryDirectory()).path}/temporary_file');
      await _file.writeAsBytes(_rawBytes.toList());
      _originalImage = Image.memory(await _file.readAsBytes());
      print("${_file.path}");
    } else {
      return false;
    }
    _stepImages.add(_originalImage); // TODO remove

    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      // Gaussian Blur
      _res = await ImgProc.gaussianBlur(
        _file.readAsBytesSync(),
        [11, 11],
        0,
      );
      _stepImages.add(Image.memory((_res))); // TODO remove

      // Adaptive Threshold
      _res = await ImgProc.adaptiveThreshold(
        _res,
        255,
        ImgProc.adaptiveThreshGaussianC,
        ImgProc.threshBinaryInv,
        5,
        2,
      );
      _stepImages.add(Image.memory((_res))); // TODO remove

      // Dilate image to fill in gaps in the border lines
      _res = await ImgProc.dilate(
        _res,
        [1, 1],
      );
      _stepImages.add(Image.memory((_res))); // TODO remove

      // TODO the rest of the steps

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
      return false;
    }
    return true;
  }

  bool _detectAndCropGrid() {
    print("adding image from bytedData");
    Image testImage = Image.memory(_binaryImageData.rawBytes);
    stepImages.add(testImage);

    // test ability to change color
    print("attempting to place colors");
    String colorChange;
    for (int i = 50; i < 100; i++) {
      for (int j = 50; j < 100; j++) {
        colorChange = "";
        colorChange += "${_binaryImageData.getPixelColorAt(i, j)} --> ";

        _binaryImageData.setPixelColorAt(i, j, Colors.white);

        colorChange += "${_binaryImageData.getPixelColorAt(i, j)}";
//        print(colorChange);
      }
    }
    print("colors placed");
    testImage = Image.memory(_binaryImageData.rawBytes);
    stepImages.add(testImage);

    // detect Blobs and flood fill them with gray

    // flood fill the largest blob with white (should be the sudoku grid)
    return true;
  }
}
