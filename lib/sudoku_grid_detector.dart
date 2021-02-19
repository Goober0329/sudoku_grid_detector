import 'dart:io';
import 'dart:math';
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

  List<Image> _stepImages = []; // TODO remove when complete

  /// Image widget getters for displaying in Flutter
  Image get originalImage => _originalImage;
  Image get binaryImage => _binaryImage;
  List<Image> get stepImages => _stepImages; // TODO remove when complete

  /// sudoku grid getters
  List<List<int>> get sudokuGrid => _sudokuGrid;

  /// main SudokuGridDetector method for finding a Sudoku grid in an image
  Future<bool> detectSudokuGrid() async {
    bool allAccordingToPlan;

    // use OpenCV to prepare the image for grid detection
    allAccordingToPlan = await _prepareImageData();
    if (!allAccordingToPlan) return false;

    // detect the grid, perform a matrix transform to show just the grid
    allAccordingToPlan = await _detectAndCropGrid();
    if (!allAccordingToPlan) return false;

    // TODO pull digits from the grid

    return allAccordingToPlan;
  }

  /// image preparation function that sets many of the class variables and
  /// creates an adaptively thresholded binary image that can be used to
  /// detect the Sudoku grids.
  Future<bool> _prepareImageData() async {
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
      _res = await ImgProc.dilate(_res, [1, 1]);
      _stepImages.add(Image.memory((_res))); // TODO remove

      print("res ${_res == null ? "does" : "doesn't"} equal null");
      _binaryImage = Image.memory((_res));
      print(
          "binaryImage ${_binaryImage == null ? "does" : "doesn't"} equal null");
      _binaryImageData = ImageData(image: await _bytesToImage(_res));
      print(
          "binaryImageData ${_binaryImageData == null ? "does" : "doesn't"} equal null");
      await _binaryImageData.imageToByteData();

      // ensure that it is truly just black or white
      // for some reason some of the pixels are not pure black/white and
      // it causes issues when doing blob detection.
      // TODO can someone figure out why the image values aren't actually binary?
      Color c;
      for (int row = 0; row < _binaryImageData.width; row++) {
        for (int col = 0; col < _binaryImageData.height; col++) {
          c = _binaryImageData.getPixelColorAt(row, col);
          if (c.computeLuminance() > 0.5) {
            _binaryImageData.setPixelColorAt(row, col, Colors.white);
          } else {
            _binaryImageData.setPixelColorAt(row, col, Colors.black);
          }
        }
      }
    } on PlatformException {
      print("some error occurred. possibly OpenCV PlatformException");
      return false;
    }
    return true;
  }

  /// detects the sudoku grid and locates its corner points.
  /// It then uses that to crop and transform the image to be just the grid
  Future<bool> _detectAndCropGrid() async {
    // detect Blobs and flood fill them with gray
    List<_Blob> blobs = [];
    Color c;
    for (int row = 0; row < _binaryImageData.height; row++) {
      for (int col = 0; col < _binaryImageData.width; col++) {
        c = _binaryImageData.getPixelColorAt(col, row);
        try {
          if (c.value == Colors.white.value) {
            _Blob blob = _Blob();
            _floodFill(
              x: col,
              y: row,
              imgData: _binaryImageData,
              blob: blob,
            );
            blobs.add(blob);
          }
        } catch (e) {
          print(e);
          print("the color of the pixel at $col, $row could not be read");
          return false;
        }
      }
    }

    // flood fill the largest blob with white (should be the sudoku grid)
    // flood fill the smaller blobs with black TODO fill blobs with black instead of gray above and then you don't have to fill all of the small blobs with black again.
    blobs.sort((b, a) => a.size.compareTo(b.size));

    int x, y;
    x = blobs[0].points[0][0];
    y = blobs[0].points[0][1];
    c = _binaryImageData.getPixelColorAt(x, y);
    _floodFill(
      x: x,
      y: y,
      toFill: c,
      fill: Colors.white,
      imgData: _binaryImageData,
    );
    stepImages.add(Image.memory(_binaryImageData.bytes)); // TODO remove

    for (int b = 1; b < blobs.length; b++) {
      x = blobs[b].points[0][0];
      y = blobs[b].points[0][1];
      c = _binaryImageData.getPixelColorAt(x, y);
      _floodFill(
        x: x,
        y: y,
        toFill: c,
        fill: Colors.black,
        imgData: _binaryImageData,
      );
    }
    stepImages.add(Image.memory(_binaryImageData.bytes)); // TODO remove

    try {
      // Erosion
      _res = await ImgProc.erode(_binaryImageData.bytes, [1, 1]);
      _binaryImageData = ImageData(image: await _bytesToImage(_res));
      await _binaryImageData.imageToByteData();
    } on PlatformException {
      print("some error occurred. possibly OpenCV PlatformException");
      return false;
    }

    // detect corners from binary grid
    List<List<int>> corners = _detectCorners(_binaryImageData, blobs[0].points);
    if (corners == null) return false;

    for (List<int> corner in corners) {
      print(corner);
    }

    // TODO remove below when all is complete.
    int size = 10;
    for (List<int> c in corners) {
      for (int i = -size ~/ 2; i <= size ~/ 2; i++) {
        for (int j = -size ~/ 2; j <= size ~/ 2; j++) {
          _binaryImageData.setPixelColorAt(c[0] + i, c[1] + j, Colors.red);
        }
      }
    }
    stepImages.add(Image.memory(_binaryImageData.bytes)); // TODO remove
    // TODO remove above when all is complete.

    // TODO grid transform
    try {
      // Perspective Transform
      int gridSize = _binaryImageData.width;
      _res = await ImgProc.warpPerspectiveTransform(
        _file.readAsBytesSync(),
        sourcePoints: [
          corners[0][0],
          corners[0][1],
          corners[1][0],
          corners[1][1],
          corners[2][0],
          corners[2][1],
          corners[3][0],
          corners[3][1],
        ],
        destinationPoints: [0, 0, gridSize, 0, 0, gridSize, gridSize, gridSize],
        outputSize: [gridSize.toDouble(), gridSize.toDouble()],
      );
      stepImages.add(Image.memory(_res));
//      _binaryImageData = ImageData(image: await _bytesToImage(_res));
//      await _binaryImageData.imageToByteData();
    } on PlatformException {
      print("some error occurred. possibly OpenCV PlatformException");
      return false;
    }

    return true;
  }

  // This function helps convert raw image data into a ui.Image Object
  Future<ui.Image> _bytesToImage(Uint8List imgBytes) async {
    ui.Codec codec = await ui.instantiateImageCodec(imgBytes);
    ui.FrameInfo frame = await codec.getNextFrame();
    return frame.image;
  }

  void _floodFill({
    @required int x,
    @required int y,
    Color toFill = Colors.white,
    Color fill = Colors.grey,
    @required ImageData imgData,
    _Blob blob,
  }) {
    // return if the coordinate point is outside of image
    if (_pixelIsOffImage(imgData, x, y)) {
      return;
    }

    // return if the coordinate is outside of the fillC
    Color c = imgData.getPixelColorAt(x, y);
    if (c.value != toFill.value) {
      return;
    }

    // set the point
    imgData.setPixelColorAt(x, y, fill);
    if (blob != null) {
      blob.addPoint(x, y);
    }

    // recursive flood fill
    _floodFill(
      x: x,
      y: y - 1,
      toFill: toFill,
      fill: fill,
      imgData: imgData,
      blob: blob,
    );
    _floodFill(
      x: x,
      y: y + 1,
      toFill: toFill,
      fill: fill,
      imgData: imgData,
      blob: blob,
    );
    _floodFill(
      x: x - 1,
      y: y,
      toFill: toFill,
      fill: fill,
      imgData: imgData,
      blob: blob,
    );
    _floodFill(
      x: x + 1,
      y: y,
      toFill: toFill,
      fill: fill,
      imgData: imgData,
      blob: blob,
    );
    return;
  }

  // center of mass calculation to determine the four furthest points (corners)
  // https://stackoverflow.com/questions/66271931/find-the-corner-points-of-a-set-of-pixels-that-make-up-a-quadrilateral-boundary/66272023?noredirect=1#comment117166203_66272023
  List<List<int>> _detectCorners(
      ImageData imgData, List<List<int>> boundaryPixels) {
    if (boundaryPixels == null || boundaryPixels.length < 4) return null;

    // get the center of mass
    double centerX = 0;
    double centerY = 0;
    for (List<int> point in boundaryPixels) {
      centerX += point[0];
      centerY += point[1];
    }
    centerX /= boundaryPixels.length;
    centerY /= boundaryPixels.length;
    print("$centerX, $centerY");

    // sort blob pixels by distance from the center
    boundaryPixels.sort(
      (b, a) => (_pointDistance(a[0], a[1], centerX.toInt(), centerY.toInt()))
          .compareTo(
        _pointDistance(b[0], b[1], centerX.toInt(), centerY.toInt()),
      ),
    );

    // remove duplicate corners
    List<List<int>> fourCorners = [boundaryPixels[0]];
    for (List<int> np in boundaryPixels) {
      bool contained = false;
      for (List<int> fcp in fourCorners) {
        if (_pointDistance(np[0], np[1], fcp[0], fcp[1]) < imgData.width / 5) {
          contained = true;
          break;
        }
      }
      if (!contained) {
        fourCorners.add(np);
      }
      if (fourCorners.length == 4) break;
    }

    // determine which cartesian quadrant each corner is in based on the grid center as origin
    // quadrants are in order: top-left, top-right, bottom-left, bottom-right
    List<int> quadrant = [0, 0, 0, 0];
    for (int i = 0; i < fourCorners.length; i++) {
      int difX = fourCorners[i][0] - centerX.toInt();
      int difY = fourCorners[i][1] - centerY.toInt();
      if (difX < 0 && difY < 0) {
        quadrant[0] = i;
      } else if (difX >= 0 && difY < 0) {
        quadrant[1] = i;
      } else if (difX < 0 && difY >= 0) {
        quadrant[2] = i;
      } else if (difX >= 0 && difY >= 0) {
        quadrant[3] = i;
      }
    }

    // return the four corner locations in order
    return [
      fourCorners[quadrant[0]],
      fourCorners[quadrant[1]],
      fourCorners[quadrant[2]],
      fourCorners[quadrant[3]],
    ];
  }

  double _pointDistance(int x1, int y1, int x2, int y2) {
    return sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));
  }

  bool _pixelIsOffImage(ImageData imgData, int x, int y) {
    return y < 0 || y >= imgData.height || x < 0 || x >= imgData.width;
  }
}

class _Blob {
  List<List<int>> points = [];

  int get size => points.length;

  void addPoint(int x, int y) {
    points.add([x, y]);
  }
}
