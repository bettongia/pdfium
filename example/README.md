# Example files

Before you try any examples, please check the main [README](../README.md) as you
need to perform a few tasks in order to get the PDFium binaries ready.

Tip: there's a bunch of test PDF files in the test directory that you can use in
your exploratory work.

All test files are designed to be run from the project root. For example, to
extract the metadata from a PDF:

```sh
dart run example/main.dart
```

Extract full text:

```sh
dart run example/extract.dart
```

## `pdfinfo`

This package include a small application named `pdfinfo` - you can get started
by calling it and seeing the usage instructions:

```sh
dart run bin/pdfinfo.dart
```
