import 'dart:io';
import 'package:DILGDOCS/screens/sidebar.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class LibraryScreen extends StatefulWidget {
  final Function(String, String)? onFileOpened;
  final Function(String)? onFileDeleted;

  LibraryScreen({
    this.onFileOpened,
    this.onFileDeleted,
  });

  @override
  _LibraryScreenState createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  TextEditingController _searchController = TextEditingController();
  List<String> downloadedFiles = [];
  List<String> filteredFiles = [];
  bool isSearching = false;
  Map<String, DateTime> downloadTimes = {};
  Map<String, bool> selectedFiles = {};
  bool selectAll = false;
  bool selectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadRootDirectory();
  }

  void _loadRootDirectory() async {
    final appDir = await getExternalStorageDirectory();
    print('Root directory path: ${appDir?.path}');
    if (appDir == null) {
      print('Error: Failed to get the root directory path');
      return;
    }

    final rootDirectory = Directory(appDir.path);
    await loadDownloadedFiles(rootDirectory);

    setState(() {
      filteredFiles.addAll(downloadedFiles);
      for (var file in downloadedFiles) {
        selectedFiles[file] = false;
      }
    });
  }

  Future<void> loadDownloadedFiles(Directory directory) async {
    List<FileSystemEntity> entities = directory.listSync();

    for (var entity in entities) {
      if (entity is Directory) {
        await loadDownloadedFiles(entity);
      } else if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
        downloadedFiles.add(entity.path);
        downloadTimes[entity.path] = entity.lastModifiedSync();
      }
    }

    downloadedFiles
        .sort((a, b) => downloadTimes[b]!.compareTo(downloadTimes[a]!));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Sidebar(
        currentIndex: 0,
        onItemSelected: (index) {
          _navigateToSelectedPage(context, index);
        },
      ),
      body: SingleChildScrollView(
        child: Container(
          margin: EdgeInsets.only(top: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSearchAndFilterRow(),
              if (selectionMode) _buildSelectAllCheckbox(),
              _buildPdf(context),
              if (selectionMode) _buildDeleteSelectedButton(),
            ],
          ),
        ),
      ),
    );
  }

  void _exitSelectionMode() {
    setState(() {
      selectionMode = false;
      for (var file in selectedFiles.keys) {
        selectedFiles[file] = false;
      }
      selectAll = false;
    });
  }

  Widget _buildSelectAllCheckbox() {
    final selectedCount =
        selectedFiles.values.where((isSelected) => isSelected).length;
    final allSelected =
        selectedCount == filteredFiles.length && filteredFiles.isNotEmpty;

    void _handleSelectAll() {
      setState(() {
        // First update all files' selection state based on whether all are currently selected
        final newSelectAll = !allSelected;
        for (var file in filteredFiles) {
          selectedFiles[file] = newSelectAll;
        }
        // Then update the selectAll state to match
        selectAll = newSelectAll;
      });
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
      child: Row(
        children: [
          // Left section - Select All/Unselect All with checkbox
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _handleSelectAll,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  child: Checkbox(
                    value: allSelected,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    onChanged: (bool? value) => _handleSelectAll(),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  allSelected ? 'Unselect All' : 'Select All',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: allSelected ? Colors.red : null,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Container(),
          ),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$selectedCount selected',
                style: TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.close, size: 20),
                onPressed: _exitSelectionMode,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteSelectedButton() {
    final selectedCount =
        selectedFiles.values.where((isSelected) => isSelected).length;
    if (selectedCount == 0) return SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: 100, maxWidth: 150),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding:
                const EdgeInsets.symmetric(vertical: 6.0, horizontal: 20.0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: _deleteSelectedFiles,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Delete ($selectedCount)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _deleteSelectedFiles() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Confirm Delete"),
          content: Text("Are you sure you want to delete the selected files?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final filesToDelete = selectedFiles.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    for (var filePath in filesToDelete) {
      try {
        File file = File(filePath);
        file.deleteSync();
        downloadedFiles.remove(filePath);
        filteredFiles.remove(filePath);
        selectedFiles.remove(filePath);
        widget.onFileDeleted?.call(filePath.split('/').last);
      } catch (e) {
        print("Failed to delete file: $e");
      }
    }

    setState(() {
      selectAll = false;
      if (selectedFiles.isEmpty) {
        selectionMode = false;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${filesToDelete.length} files deleted successfully'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      child: Expanded(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.5),
                spreadRadius: 2,
                blurRadius: 5,
                offset: Offset(0, 3),
              )
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      border: InputBorder.none,
                    ),
                    onChanged: (value) {
                      _filterFiles(value);
                    },
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.search),
                onPressed: () {
                  _filterFiles(_searchController.text);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _buildSearchBar(),
              SizedBox(width: 10),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPdf(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (filteredFiles.isEmpty)
          Container(
            margin: EdgeInsets.only(top: 15), // Added margin top here
            child: Center(
              child: Text(
                'No downloaded issuances',
                style: TextStyle(
                  fontSize: 18,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),
        if (filteredFiles.isNotEmpty)
          Column(
            children: [
              SizedBox(height: 15),
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: filteredFiles.length,
                itemBuilder: (BuildContext context, int index) {
                  final String file = filteredFiles[index];
                  final fileName = file.split('/').last;
                  return Dismissible(
                    key: Key(file),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: EdgeInsets.symmetric(horizontal: 20.0),
                      child: Icon(
                        Icons.delete,
                        color: Colors.white,
                      ),
                    ),
                    confirmDismiss: (direction) async {
                      return await _showDeleteConfirmationDialog(context, file);
                    },
                    onDismissed: (direction) {
                      _deleteFile(file);
                    },
                    child: InkWell(
                      onLongPress: () {
                        if (!selectionMode) {
                          setState(() {
                            selectionMode = true;
                            selectedFiles[file] = true;
                          });
                        }
                      },
                      onTap: () {
                        if (selectionMode) {
                          setState(() {
                            selectedFiles[file] =
                                !(selectedFiles[file] ?? false);
                          });
                        } else {
                          openPdfViewer(
                            context,
                            file,
                            widget.onFileOpened ??
                                (String fileName, String filePath) {},
                          );
                        }
                      },
                      child: ListTile(
                        leading: selectionMode
                            ? Checkbox(
                                value: selectedFiles[file] ?? false,
                                onChanged: (bool? value) {
                                  setState(() {
                                    selectedFiles[file] = value ?? false;
                                  });
                                },
                              )
                            : Icon(
                                Icons.picture_as_pdf,
                                color: Colors.blue,
                              ),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (!selectionMode) SizedBox(width: 10),
                                Expanded(
                                  child: _buildHighlightedTitle(fileName),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Container(
                              height: 0.5,
                              color: Colors.black,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildHighlightedTitle(String title) {
    final RegExp regex = RegExp(_searchController.text, caseSensitive: false);
    final Iterable<Match> matches = regex.allMatches(title);

    final List<TextSpan> children = [];
    int start = 0;
    for (Match match in matches) {
      if (match.start != start) {
        children.add(
          TextSpan(
            text: _truncateFilename(title.substring(start, match.start)),
            style: TextStyle(
              fontSize: 16,
              color: Colors.black,
              fontFamily: 'Poppins',
            ),
          ),
        );
      }
      children.add(
        TextSpan(
          text: title.substring(match.start, match.end),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
            fontFamily: 'Poppins',
          ),
        ),
      );
      start = match.end;
    }

    if (start != title.length) {
      children.add(
        TextSpan(
          text: _truncateFilename(title.substring(start)),
          style: TextStyle(
            fontSize: 16,
            color: Colors.black,
            fontFamily: 'Poppins',
          ),
        ),
      );
    }

    return RichText(
      text: TextSpan(
        children: children,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 2,
    );
  }

  String _truncateFilename(String fileName, {int maxLength = 50}) {
    if (fileName.length <= maxLength) {
      return fileName;
    } else {
      return fileName.substring(0, maxLength - 3) + '...';
    }
  }

  void _filterFiles(String query) {
    setState(() {
      filteredFiles = downloadedFiles
          .where((file) => file.toLowerCase().contains(query.toLowerCase()))
          .toList();
      selectAll = false;
    });
  }

  Future<bool> _showDeleteConfirmationDialog(
      BuildContext context, String filePath) async {
    bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Confirm Delete"),
          content: Text("Are you sure you want to delete this file?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                _deleteFile(filePath);
              },
              child: Text("Delete"),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  void _deleteFile(String filePath) {
    try {
      File file = File(filePath);
      file.deleteSync();
      downloadedFiles.remove(filePath);
      filteredFiles.remove(filePath);
      selectedFiles.remove(filePath);

      widget.onFileDeleted?.call(filePath.split('/').last);

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Success"),
            content: Text("The file has been successfully deleted."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: Text("OK"),
              ),
            ],
          );
        },
      );

      setState(() {});
    } catch (e) {
      print("Failed to delete file: $e");
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Error"),
            content: Text("Failed to delete the file."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text("OK"),
              ),
            ],
          );
        },
      );
    }
  }

  void _navigateToSelectedPage(BuildContext context, int index) {
    // Handle navigation to selected page
  }

  Future<void> openPdfViewer(BuildContext context, String filePath,
      Function(String, String) onFileOpened) async {
    String fileName = filePath.split('/').last;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PDFViewerScreen(
          filePath: filePath,
          fileName: fileName,
        ),
      ),
    );
    onFileOpened(fileName, filePath);
  }
}

class PDFViewerScreen extends StatelessWidget {
  final String filePath;
  final String fileName;
  final Function(String, String)? onFileOpened;
  final Function(String)? onFileDeleted;

  PDFViewerScreen(
      {required this.filePath,
      required this.fileName,
      this.onFileOpened,
      this.onFileDeleted});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName),
      ),
      body: FutureBuilder<File>(
        future: _getFile(filePath),
        builder: (BuildContext context, AsyncSnapshot<File> snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.hasData) {
            return SfPdfViewer.file(snapshot.data!);
          } else if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          } else {
            return Center(
              child: CircularProgressIndicator(),
            );
          }
        },
      ),
    );
  }

  Future<File> _getFile(String filePath) async {
    File file = File(filePath);
    if (await file.exists()) {
      return file;
    } else {
      throw 'File not found: $filePath';
    }
  }
}

// import 'dart:io';
// import 'package:DILGDOCS/screens/sidebar.dart';
// import 'package:flutter/material.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

// class LibraryScreen extends StatefulWidget {
//   final Function(String, String)? onFileOpened;
//   final Function(String)? onFileDeleted;

//   LibraryScreen({
//     this.onFileOpened,
//     this.onFileDeleted,
//   });

//   @override
//   _LibraryScreenState createState() => _LibraryScreenState();
// }

// class _LibraryScreenState extends State<LibraryScreen> {
//   TextEditingController _searchController = TextEditingController();
//   List<String> downloadedFiles = [];
//   List<String> filteredFiles = [];
//   bool isSearching = false;
//   Map<String, DateTime> downloadTimes = {};

//   @override
//   void initState() {
//     super.initState();
//     _loadRootDirectory();
//   }

//   void _loadRootDirectory() async {
//     final appDir = await getExternalStorageDirectory();
//     print('Root directory path: ${appDir?.path}');
//     if (appDir == null) {
//       print('Error: Failed to get the root directory path');
//       return;
//     }

//     final rootDirectory = Directory(appDir.path);
//     await loadDownloadedFiles(rootDirectory);

//     setState(() {
//       filteredFiles.addAll(downloadedFiles);
//     });
//   }

//   Future<void> loadDownloadedFiles(Directory directory) async {
//     List<FileSystemEntity> entities = directory.listSync();

//     for (var entity in entities) {
//       if (entity is Directory) {
//         // Check if entity is a directory before recursively calling loadDownloadedFiles
//         await loadDownloadedFiles(entity);
//       } else if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
//         downloadedFiles.add(entity.path);

//         // Store download time
//         downloadTimes[entity.path] = entity.lastModifiedSync();
//       }
//     }

//     // Sort files based on download time
//     downloadedFiles.sort((a, b) => downloadTimes[b]!.compareTo(downloadTimes[a]!));
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       drawer: Sidebar(
//         currentIndex: 0,
//         onItemSelected: (index) {
//           _navigateToSelectedPage(context, index);
//         },
//       ),
//       body: SingleChildScrollView(
//         child: Container(
//           margin: EdgeInsets.only(top: 16.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               _buildSearchAndFilterRow(),
//               _buildPdf(context),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildSearchBar() {
//     return Container(
//       child: Expanded(
//         child: Container(
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(10),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.grey.withOpacity(0.5),
//                 spreadRadius: 2,
//                 blurRadius: 5,
//                 offset: Offset(0, 3),
//               ),
//             ],
//           ),
//           child: Row(
//             children: [
//               Expanded(
//                 child: Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 16),
//                   child: TextField(
//                     controller: _searchController,
//                     decoration: InputDecoration(
//                       hintText: 'Search...',
//                       border: InputBorder.none,
//                     ),
//                     onChanged: (value) {
//                       _filterFiles(value);
//                     },
//                   ),
//                 ),
//               ),
//               IconButton(
//                 icon: Icon(Icons.search),
//                 onPressed: () {
//                   _filterFiles(_searchController.text);
//                 },
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildSearchAndFilterRow() {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 20),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.stretch,
//         children: [
//           Row(
//             children: [
//               _buildSearchBar(),
//               SizedBox(width: 10),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPdf(BuildContext context) {
//   return Column(
//     crossAxisAlignment: CrossAxisAlignment.stretch,
//     children: [
//       SizedBox(height: 16),
//       if (filteredFiles.isEmpty)
//         Center(
//           child: Text(
//             'No downloaded issuances',
//             style: TextStyle(
//               fontSize: 18,
//               fontFamily: 'Poppins', // Apply font family here
//             ),
//           ),
//         ),
//       if (filteredFiles.isNotEmpty)
//         Column(
//           children: [
//             SizedBox(height: 10),
//             ListView.builder(
//               shrinkWrap: true,
//               physics: NeverScrollableScrollPhysics(),
//               itemCount: filteredFiles.length,
//               itemBuilder: (BuildContext context, int index) {
//                 final String file = filteredFiles[index];
//                 final fileName = file.split('/').last;
//                 return Dismissible(
//                   key: Key(file), // Unique key for each item
//                   direction: DismissDirection.endToStart, // Swipe direction
//                   background: Container(
//                     color: Colors.red, // Background color when swiping
//                     alignment: Alignment.centerRight,
//                     padding: EdgeInsets.symmetric(horizontal: 20.0),
//                     child: Icon(
//                       Icons.delete,
//                       color: Colors.white,
//                     ),
//                   ),
//                   confirmDismiss: (direction) async {
//                     // Show confirmation dialog when swiping
//                     return await _showDeleteConfirmationDialog(context, file);
//                   },
//                   onDismissed: (direction) {
//                     // Delete the item when dismissed
//                     _deleteFile(file);
//                   },
//                   child: ListTile(
//                     title: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Row(
//                           children: [
//                             Icon(
//                               Icons.picture_as_pdf,
//                               color: Colors.blue,
//                             ),
//                             SizedBox(width: 10),
//                             Expanded(
//                               child: _buildHighlightedTitle(fileName),
//                             ),
//                           ],
//                         ),
//                         SizedBox(height: 4),
//                         Container(
//                           height: 0.5,
//                           color: Colors.black,
//                         ),
//                       ],
//                     ),
//                     onTap: () {
//                       openPdfViewer(
//                         context,
//                         file,
//                         widget.onFileOpened ??
//                             (String fileName, String filePath) {},
//                       );
//                     },
//                   ),
//                 );
//               },
//             ),
//           ],
//         ),
//     ],
//   );
// }



//   Widget _buildHighlightedTitle(String title) {
//     final RegExp regex = RegExp(_searchController.text, caseSensitive: false);
//     final Iterable<Match> matches = regex.allMatches(title);

//     final List<TextSpan> children = [];
//     int start = 0;
//     for (Match match in matches) {
//       if (match.start != start) {
//         children.add(
//           TextSpan(
//             text: _truncateFilename(title.substring(start, match.start)),
//             style: TextStyle(
//               fontSize: 16,
//               color: Colors.black,
//               fontFamily: 'Poppins',
//             ),
//           ),
//         );
//       }
//       children.add(
//         TextSpan(
//           text: title.substring(match.start, match.end),
//           style: TextStyle(
//             fontSize: 16,
//             fontWeight: FontWeight.bold,
//             color: Colors.blue,
//             fontFamily: 'Poppins',
//           ),
//         ),
//       );
//       start = match.end;
//     }

//     if (start != title.length) {
//       children.add(
//         TextSpan(
//           text: _truncateFilename(title.substring(start)),
//           style: TextStyle(
//             fontSize: 16,
//             color: Colors.black,
//              fontFamily: 'Poppins',
//           ),
//         ),
//       );
//     }

//     return RichText(
//       text: TextSpan(
//         children: children,
//       ),
//       overflow: TextOverflow.ellipsis,
//       maxLines: 2,
//     );
//   }

//   String _truncateFilename(String fileName, {int maxLength = 20}) {
//     if (fileName.length <= maxLength) {
//       return fileName;
//     } else {
//       return fileName.substring(0, maxLength - 3) + '...';
//     }
//   }

//   void _filterFiles(String query) {
//     setState(() {
//       filteredFiles = downloadedFiles
//           .where((file) => file.toLowerCase().contains(query.toLowerCase()))
//           .toList();
//     });
//   }

//   Future<bool> _showDeleteConfirmationDialog(
//       BuildContext context, String filePath) async {
//     bool? result = await showDialog<bool>(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text("Confirm Delete"),
//           content: Text("Are you sure you want to delete this file?"),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(context).pop(false); // Return false when cancelled
//               },
//               child: Text("Cancel"),
//             ),
//             TextButton(
//               onPressed: () {
//                 _deleteFile(filePath); // Delete the file when confirmed
//               },
//               child: Text("Delete"),
//             ),
//           ],
//         );
//       },
//     );
//     return result ?? false;
//   }

//   void _deleteFile(String filePath) {
//   try {
//     File file = File(filePath);
//     file.deleteSync();
//     downloadedFiles.remove(filePath);
//     filteredFiles.remove(filePath);

//     // Call the onFileDeleted function provided by HomeScreen
//     widget.onFileDeleted?.call(filePath.split('/').last);

//     // Show a confirmation dialog
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text("Success"),
//           content: Text("The file has been successfully deleted."),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(context).pop(); // Dismiss the success dialog
//                 Navigator.of(context)
//                     .pop(); // Dismiss the confirmation dialog
//               },
//               child: Text("OK"),
//             ),
//           ],
//         );
//       },
//     );

//     setState(() {});
//   } catch (e) {
//     print("Failed to delete file: $e");
//     // Show an error dialog if deletion fails
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text("Error"),
//           content: Text("Failed to delete the file."),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//               child: Text("OK"),
//             ),
//           ],
//         );
//       },
//     );
//   }
// }

//   void _navigateToSelectedPage(BuildContext context, int index) {
//     // Handle navigation to selected page
//   }

//  Future<void> openPdfViewer(BuildContext context, String filePath,
//       Function(String, String) onFileOpened) async {
//   String fileName = filePath.split('/').last; // Move this line above MaterialPageRoute
//   await Navigator.push(
//     context,
//     MaterialPageRoute(
//       builder: (context) => PDFViewerScreen(
//         filePath: filePath,
//         fileName: fileName, // Use the fileName here
     
//       ),
//     ),
//   );
//   onFileOpened(fileName, filePath);
// }


// }

// class PDFViewerScreen extends StatelessWidget {
//   final String filePath;
//   final String fileName;
//   final Function(String, String)? onFileOpened;
//   final Function(String)? onFileDeleted; // Add onFileDeleted function

//   PDFViewerScreen({required this.filePath, required this.fileName, this.onFileOpened, this.onFileDeleted});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(fileName), // Use the truncated filename in the app bar title
//       ),
//       body: FutureBuilder<File>(
//         future: _getFile(filePath),
//         builder: (BuildContext context, AsyncSnapshot<File> snapshot) {
//           if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
//             return SfPdfViewer.file(snapshot.data!);
//           } else if (snapshot.hasError) {
//             return Center(
//               child: Text('Error: ${snapshot.error}'),
//             );
//           } else {
//             return Center(
//               child: CircularProgressIndicator(),
//             );
//           }
//         },
//       ),
//     );
//   }

//   Future<File> _getFile(String filePath) async {
//     File file = File(filePath);
//     if (await file.exists()) {
//       return file;
//     } else {
//       throw 'File not found: $filePath';
//     }
//   }

//   // @override
//   // void dispose() {
//   //   super.dispose();
//   //   // Call onFileOpened function when disposing the PDFViewerScreen
//   //   if (onFileOpened != null) {
//   //     onFileOpened!(fileName, filePath);
//   //   }
//   // }
// }