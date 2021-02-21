import 'package:flutter/material.dart';
import 'package:sudoku_grid_detector/sudoku_grid_detector.dart';
import 'package:image/image.dart' as img;

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<Image> steps = [];
  List<Image> digits = [];
  List<List<double>> points;

  void runDetector() async {
    print("running detector");
    SudokuGridDetector detector = SudokuGridDetector.fromAsset("sudoku.jpeg");
    bool gotGrid = await detector.detectSudokuGrid();
    if (gotGrid) {
      setState(() {
        steps = detector.stepImages;
        digits = detector.digitImages;
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
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: steps.length,
                itemBuilder: (BuildContext context, int index) {
                  return Container(
                    child: steps[index],
                  );
                },
              ),
            ),
            Expanded(
              child: GridView.count(
                crossAxisCount: 9,
                crossAxisSpacing: 1,
                mainAxisSpacing: 1,
                children: digits,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
