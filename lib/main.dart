import 'package:flutter/material.dart';
import 'package:sudoku_grid_detector/sudoku_grid_detector.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<Image> steps = [];
  List<List<double>> points;

  void runDetector() async {
    print("running detector");
    SudokuGridDetectorModified detector =
        SudokuGridDetectorModified.fromAsset("sudoku.jpeg");
    bool gotGrid = await detector.detectSudokuGrid();
    if (gotGrid) {
      setState(() {
//        original = detector.originalImage;
//        binary = detector.binaryImage;
        steps = detector.stepImages;
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
          child: Icon(Icons.thumb_up),
          onPressed: () {
            runDetector();
          },
        ),
        body: Center(
          child: ListView.builder(
            itemCount: steps.length,
            itemBuilder: (BuildContext context, int index) {
              return Container(
//                width: 300,
                child: steps[index],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> getPointWidgets(List<List<double>> points, int w, int h) {
    List<Widget> toReturn = [];

    for (List<double> point in points) {
      toReturn.add(
        Positioned(
          left: point[0] * w,
          top: point[1] * h,
          child: CircleAvatar(
            radius: 2,
            backgroundColor: Colors.red,
          ),
        ),
      );
    }

    return toReturn;
  }
}
