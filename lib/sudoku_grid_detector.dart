import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:opencv/opencv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

class SudokuGridDetector {
  // The code in this class is based on the tutorial by Neeramitra Reddy
  // https://medium.com/analytics-vidhya/smart-sudoku-solver-using-opencv-and-tensorflow-in-python3-3c8f42ca80aa

  static const int _cWhite = 0xFFFFFFFF;
  static const int _cGray = 0xFF9F9F9F;
  static const int _cMiddle = 0xFF808080;
  static const int _cBlack = 0x00000000;

  String _assetName;
  File _file;
  Uint8List _rawBytes;

  img.Image _originalImage;
  img.Image _binaryImage;
  img.Image _imageToWarp;
  img.Image _gridTransformImage;

  List<img.Image> _digitImages;
  List<List<int>> _sudokuGrid;

  SudokuGridDetector.fromAsset(String assetName) : this._assetName = assetName;
  SudokuGridDetector.fromFile(File file) : this._file = file;
  SudokuGridDetector.fromBytes(Uint8List bytes) : this._rawBytes = bytes;

  List<Image> stepImages = []; // TODO remove when complete
  List<Image> digitImages = []; // TODO remove when complete

  Image get originalImage => Image.memory(img.encodeJpg(_originalImage));

  /// main SudokuGridDetector method for finding a Sudoku grid in an image
  Future<bool> detectSudokuGrid() async {
    bool allAccordingToPlan;

    // use OpenCV to prepare the image for grid detection
    allAccordingToPlan = await _prepareImageData();
    if (!allAccordingToPlan) return false;

    // detect the grid, perform a matrix transform to show just the grid
    allAccordingToPlan = await _detectAndCropGrid();
    if (!allAccordingToPlan) return false;

    // crop the grid to obtain the digit images and extract digits
    allAccordingToPlan = _extractDigits();
    if (!allAccordingToPlan) return false;

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
      _originalImage = img.decodeImage(_file.readAsBytesSync());
    } else if (_file != null) {
      // image from File
      _originalImage = img.decodeImage(_file.readAsBytesSync());
    } else if (_rawBytes != null) {
      // TODO
    } else {
      return false;
    }

    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      // Gaussian Blur
      Uint8List res = await ImgProc.gaussianBlur(
        _file.readAsBytesSync(),
        [7, 7],
        0,
      );

      // Adaptive Threshold
      res = await ImgProc.adaptiveThreshold(
        res,
        255,
        ImgProc.adaptiveThreshGaussianC,
        ImgProc.threshBinaryInv,
        5,
        2,
      );

      _binaryImage = img.decodeImage(res);

      _makeTrueBinary(_binaryImage);

      _imageToWarp = _binaryImage.clone();

      stepImages.add(Image.memory(img.encodeJpg(_binaryImage))); // TODO remove
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
    List<Blob> blobs = [];
    int c;
    for (int row = 0; row < _binaryImage.height; row++) {
      for (int col = 0; col < _binaryImage.width; col++) {
        c = _binaryImage.getPixel(col, row);
        try {
          if (c == _cWhite) {
            Blob blob = Blob();
            _floodFill(
              x: col,
              y: row,
              imgData: _binaryImage,
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
    // flood fill the smaller blobs with black
    blobs.sort((b, a) => a.size.compareTo(b.size));

    int x, y;
    x = blobs[0].points[0][0];
    y = blobs[0].points[0][1];
    c = _binaryImage.getPixel(x, y);
    _floodFill(
      x: x,
      y: y,
      toFill: c,
      fill: _cWhite,
      imgData: _binaryImage,
    );

    for (int b = 1; b < blobs.length; b++) {
      x = blobs[b].points[0][0];
      y = blobs[b].points[0][1];
      c = _binaryImage.getPixel(x, y);
      _floodFill(
        x: x,
        y: y,
        toFill: c,
        fill: _cBlack,
        imgData: _binaryImage,
      );
    }

    // detect corners from binary grid
    List<List<int>> corners = _detectCorners(blobs[0]);
    if (corners == null) return false;

    for (List<int> corner in corners) {
      print(corner);
    }

    try {
      // Perspective Transform
      int gridTransformSize = _binaryImage.width;
      Uint8List res = await ImgProc.warpPerspectiveTransform(
        img.encodeJpg(_imageToWarp),
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
        destinationPoints: [
          0,
          0,
          gridTransformSize,
          0,
          0,
          gridTransformSize,
          gridTransformSize,
          gridTransformSize,
        ],
        outputSize: [
          gridTransformSize.toDouble(),
          gridTransformSize.toDouble(),
        ],
      );
      _gridTransformImage = img.decodeImage(res);
      stepImages
          .add(Image.memory(img.encodeJpg(_gridTransformImage))); // TODO remove
    } on PlatformException {
      print("some error occurred. OpenCV PlatformException");
      return false;
    }
    return true;
  }

  // center of mass calculation to determine the four furthest points (corners)
  // https://stackoverflow.com/questions/66271931/find-the-corner-points-of-a-set-of-pixels-that-make-up-a-quadrilateral-boundary/66272023?noredirect=1#comment117166203_66272023
  List<List<int>> _detectCorners(Blob gridBlob) {
    if (gridBlob.points == null || gridBlob.points.length < 4) return null;

    // get the center of mass
    gridBlob.calculateCenterOfMass();
    int centerX = gridBlob.cX;
    int centerY = gridBlob.cY;
    print("$centerX, $centerY");

    // sort blob pixels by distance from the center
    gridBlob.points.sort(
      (b, a) => (_pointDistance(a[0], a[1], centerX.toInt(), centerY.toInt()))
          .compareTo(
        _pointDistance(b[0], b[1], centerX.toInt(), centerY.toInt()),
      ),
    );

    double furthestDist = _pointDistance(
      centerX.toInt(),
      centerY.toInt(),
      gridBlob.points[0][0],
      gridBlob.points[0][1],
    );

    // remove duplicate corners
    List<List<int>> fourCorners = [gridBlob.points[0]];
    for (List<int> np in gridBlob.points) {
      bool contained = false;
      for (List<int> fcp in fourCorners) {
        if (_pointDistance(np[0], np[1], fcp[0], fcp[1]) < furthestDist / 2) {
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

  bool _extractDigits() {
    _cropDigits();

    for (int i = 0; i < _digitImages.length; i++) {
      _cleanDigit(_digitImages[i], threshold: 0.05);
      digitImages
          .add(Image.memory(img.encodeJpg(_digitImages[i]))); // TODO remove
    }

    // TODO

    return true;
  }

  // function takes the warp transformed grid and cuts out the
  // individual grid cells in preparation for digit extraction
  void _cropDigits() {
    // crop out each digit
    _digitImages = [];
    int nSquares = 9;
    int squareSize = (_gridTransformImage.width / 9).ceil();
    int error = (squareSize / 15).ceil();
    for (int row = 0; row < nSquares; row++) {
      for (int col = 0; col < nSquares; col++) {
        // do bound checking
        int x = col * squareSize - error;
        int y = row * squareSize - error;
        int w = squareSize + error * 2;
        int h = squareSize + error * 2;

        if (x + w >= _gridTransformImage.width) {
          x = _gridTransformImage.width - 1 - w;
        }
        if (y + h >= _gridTransformImage.height) {
          y = _gridTransformImage.width - 1 - h;
        }

        img.Image temp = img.copyCrop(_gridTransformImage, x, y, w, h);
        _makeTrueBinary(temp);
        _digitImages.add(temp);
      }
    }
  }

  // cleans the cropped digit squares and centers the numbers
  void _cleanDigit(img.Image digitImage, {double threshold = 0.01}) {
    // loop over border and flood fill with black
    // top and bottom border
    for (int col = 0; col < digitImage.width; col++) {
      if (digitImage.getPixel(col, 0) == _cWhite) {
        _floodFill(
          x: col,
          y: 0,
          imgData: digitImage,
          toFill: _cWhite,
          fill: _cBlack,
        );
      }
      if (digitImage.getPixel(col, digitImage.height - 1) == _cWhite) {
        _floodFill(
          x: col,
          y: digitImage.height - 1,
          imgData: digitImage,
          toFill: _cWhite,
          fill: _cBlack,
        );
      }
    }

    // left and right border
    for (int row = 0; row < digitImage.height; row++) {
      if (digitImage.getPixel(0, row) == _cWhite) {
        _floodFill(
          x: 0,
          y: row,
          imgData: digitImage,
          toFill: _cWhite,
          fill: _cBlack,
        );
      }
      if (digitImage.getPixel(digitImage.width - 1, row) == _cWhite) {
        _floodFill(
          x: digitImage.width - 1,
          y: row,
          imgData: digitImage,
          toFill: _cWhite,
          fill: _cBlack,
        );
      }
    }

    // count blobs that intersect with the center of the image
    List<Blob> blobs = [];
    int c;
    // loop horizontal
    int row = digitImage.height ~/ 2;
    for (int col = 0; col < digitImage.width; col++) {
      c = digitImage.getPixel(col, row);
      try {
        if (c == _cWhite) {
          Blob blob = Blob();
          _floodFill(
            x: col,
            y: row,
            imgData: digitImage,
            toFill: _cWhite,
            fill: _cGray,
            blob: blob,
          );
          blobs.add(blob);
        }
      } catch (e) {
        print(e);
        print("the color of the pixel at $col, $row could not be read");
        return;
      }
    }
    // loop vertical
    int col = digitImage.width ~/ 2;
    for (int row = 0; row < digitImage.height; row++) {
      c = digitImage.getPixel(col, row);
      try {
        if (c == _cWhite) {
          Blob blob = Blob();
          _floodFill(
            x: col,
            y: row,
            imgData: digitImage,
            toFill: _cWhite,
            fill: _cGray,
            blob: blob,
          );
          blobs.add(blob);
        }
      } catch (e) {
        print(e);
        print("the color of the pixel at $col, $row could not be read");
        return;
      }
    }

    // fill image with black
    digitImage.fill(_cBlack);

    // find largest and is large enough?
    blobs.sort((b, a) => a.size.compareTo(b.size));
    if (blobs.length == 0) return;
    if (blobs[0].size > threshold * digitImage.width * digitImage.height) {
      // calculate blob center of mass
      blobs[0].calculateCenterOfMass();
      int bcx = blobs[0].cX;
      int bcy = blobs[0].cY;

      // move blob to center of image
      int blobDifX = digitImage.width ~/ 2 - bcx;
      int blobDifY = digitImage.height ~/ 2 - bcy;
      for (List<int> point in blobs[0].points) {
        digitImage.setPixel(point[0] + blobDifX, point[1] + blobDifY, _cWhite);
      }
    }
  }

  // ensure that it is truly just black or white
  // for some reason some of the pixels are not pure black/white and
  // it causes issues when doing blob detection.
  // I think this is due to the img.decode function that is being used after
  // OpenCV function operations
  void _makeTrueBinary(img.Image img) {
    int c;
    for (int row = 0; row < img.height; row++) {
      for (int col = 0; col < img.width; col++) {
        c = img.getPixel(col, row);
        if (c < _cMiddle) {
          img.setPixel(col, row, _cBlack);
        } else {
          img.setPixel(col, row, _cWhite);
        }
      }
    }
  }

  void _floodFill({
    @required int x,
    @required int y,
    int toFill = _cWhite,
    int fill = _cGray,
    @required img.Image imgData,
    Blob blob,
  }) {
    // return if the coordinate point is outside of image
    if (_pixelIsOffImage(imgData, x, y)) {
      return;
    }

    // return if the coordinate is outside of the fillC
    int c = imgData.getPixel(x, y);
    if (c != toFill) {
      return;
    }

    // set the point
    imgData.setPixel(x, y, fill);
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

  // distance between two points
  double _pointDistance(int x1, int y1, int x2, int y2) {
    return sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));
  }

  // false if point is outside of imgData boundaries
  bool _pixelIsOffImage(img.Image imgData, int x, int y) {
    return y < 0 || y >= imgData.height || x < 0 || x >= imgData.width;
  }
}

class Blob {
  List<List<int>> points = [];

  int _massX = 0;
  int _massY = 0;
  List<int> _centerOfMass = [-1, -1];

  int get size => points.length;
  int get cX => _centerOfMass[0];
  int get cY => _centerOfMass[1];

  void addPoint(int x, int y) {
    points.add([x, y]);
    _massX += x;
    _massY += y;
  }

  void calculateCenterOfMass() {
    _centerOfMass[0] = _massX ~/ size;
    _centerOfMass[1] = _massY ~/ size;
  }
}
