import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:sudoku_grid_detector/sudoku_grid_detector.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Image original, binary;

  void runDetector() async {
    print("running detector");
    SudokuGridDetector detector = SudokuGridDetector.fromAsset("sudoku.jpeg");
    bool gotGrid = await detector.detectSudokuGrid();
    if (gotGrid) {
      setState(() {
        original = detector.originalImage;
        binary = detector.binaryImage;
      });
      print("got grid!");
    } else {
      print("didn't get grid");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            runDetector();
          },
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              original == null
                  ? Container()
                  : Container(
                      width: 225,
                      child: original,
                    ),
              binary == null
                  ? Container()
                  : Container(
                      width: 225,
                      child: binary,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
