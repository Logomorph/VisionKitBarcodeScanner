# VisionKitBarcodeScanner
VisionKit based barcode scanner with support for inverted barcodes

Supports all the barcode types supported by VisionKit (list available here: https://developer.apple.com/documentation/vision/vnbarcodesymbology). Please note, availability depends on device, although almost all supported devices can handle all of them.

While inverted barcode scanning can work by default, it is inconsistent, so I added a switch that inverts the image and helps the scanning.
