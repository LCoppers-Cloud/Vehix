# Vendor Classifier Model

This file is a placeholder for the `VendorClassifier.mlmodel` that should be created using Create ML.

## Instructions for Creating the Model

1. Create a CSV file containing at least two columns:
   - `text`: Raw vendor name text from receipts 
   - `label`: Canonical vendor name (normalized)

2. Use Create ML to train a text classifier:

```swift
import CreateML
import Foundation

// 1) Prepare a CSV with columns: "text" (raw vendor strings) and "label" (canonical vendor name)
let dataURL = URL(fileURLWithPath: "/path/to/vendor_training.csv")
let dataTable = try MLDataTable(contentsOf: dataURL)

// 2) Split into train/test
let (train, test) = dataTable.randomSplit(by: 0.8, seed: 42)

// 3) Train a text classifier
let classifier = try MLTextClassifier(trainingData: train,
                                      textColumn: "text",
                                      labelColumn: "label",
                                      parameters: .init(algorithm: .maxEnt(revision: 1)))

// 4) Evaluate
let eval = classifier.evaluation(on: test)
print("Accuracy: \(eval.accuracy)")

// 5) Export the .mlmodel
let outURL = URL(fileURLWithPath: "/path/to/VendorClassifier.mlmodel")
try classifier.write(to: outURL)
```

3. Import the generated `.mlmodel` file into your Xcode project

## Example Training Data

Here's an example of what your training data CSV might look like:

```
text,label
AutoZone,AutoZone Inc.
Auto Zone,AutoZone Inc.
Autozone #123,AutoZone Inc.
AUTOZONE STORE #543,AutoZone Inc.
O'Reilly Auto Parts,O'Reilly Automotive
OReillyAuto,O'Reilly Automotive
O'REILLY AUTO #235,O'Reilly Automotive
O'Reilly Automotive,O'Reilly Automotive
Napa Auto Parts,NAPA Auto Parts
NAPA,NAPA Auto Parts
NAPA Parts Store,NAPA Auto Parts
Advance Auto,Advance Auto Parts
AdvanceAutoParts,Advance Auto Parts
Advance Auto Parts #432,Advance Auto Parts
```

## Usage Notes

- The model should be periodically retrained with new data as you approve vendors in the app
- Consider adding metadata where needed (e.g., address information, contact details)
- For best results, include as many variations of vendor names as possible 