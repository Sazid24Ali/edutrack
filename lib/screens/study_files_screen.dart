import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:open_file/open_file.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;

class StudyFolder {
  String name;
  List<String> files;

  StudyFolder({required this.name, required this.files});

  Map<String, dynamic> toJson() => {'name': name, 'files': files};
  factory StudyFolder.fromJson(Map<String, dynamic> json) =>
      StudyFolder(name: json['name'], files: List<String>.from(json['files']));
}

class StudyFilesScreen extends StatefulWidget {
  const StudyFilesScreen({super.key});

  @override
  State<StudyFilesScreen> createState() => _StudyFilesScreenState();
}

class _StudyFilesScreenState extends State<StudyFilesScreen> {
  List<StudyFolder> folders = [];
  List<String> files = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final foldersJson = prefs.getStringList('studyFolders') ?? [];
    final filesJson = prefs.getStringList('files') ?? [];

    setState(() {
      folders = foldersJson
          .map((f) => StudyFolder.fromJson(jsonDecode(f)))
          .toList();
      files = filesJson;
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final foldersJson = folders.map((f) => jsonEncode(f.toJson())).toList();
    await prefs.setStringList('studyFolders', foldersJson);
    await prefs.setStringList('files', files);
  }

  Future<void> _addFolder() async {
    String folderName = '';
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          onChanged: (val) => folderName = val,
          decoration: const InputDecoration(hintText: 'Folder name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (folderName.trim().isNotEmpty) {
                setState(() {
                  folders.add(StudyFolder(name: folderName.trim(), files: []));
                  _saveData();
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _renameFolder(StudyFolder folder) async {
    String folderName = folder.name;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(
          onChanged: (val) => folderName = val,
          controller: TextEditingController(text: folder.name),
          decoration: const InputDecoration(hintText: 'Folder name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (folderName.trim().isNotEmpty) {
                setState(() {
                  folder.name = folderName.trim();
                  _saveData();
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Future<void> _renameFile(String filePath, {StudyFolder? folder}) async {
  //   String newName = path.basename(filePath);
  //   await showDialog(
  //     context: context,
  //     builder: (_) => AlertDialog(
  //       title: const Text('Rename File'),
  //       content: TextField(
  //         onChanged: (val) => newName = val,
  //         controller: TextEditingController(text: path.basename(filePath)),
  //         decoration: const InputDecoration(hintText: 'File name'),
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: const Text('Cancel'),
  //         ),
  //         TextButton(
  //           onPressed: () {
  //             if (newName.trim().isNotEmpty) {
  //               setState(() {
  //                 final newPath = path.join(
  //                   path.dirname(filePath),
  //                   newName + path.extension(filePath),
  //                 );
  //                 if (folder != null) {
  //                   final index = folder.files.indexOf(filePath);
  //                   folder.files[index] = newPath;
  //                 } else {
  //                   final index = files.indexOf(filePath);
  //                   files[index] = newPath;
  //                 }
  //                 _saveData();
  //               });
  //             }
  //             Navigator.pop(context);
  //           },
  //           child: const Text('Save'),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Future<void> _renameFile(String filePath, {StudyFolder? folder}) async {
    String newName = path.basenameWithoutExtension(filePath);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename File'),
        content: TextField(
          onChanged: (val) => newName = val,
          controller: TextEditingController(
            text: path.basenameWithoutExtension(filePath),
          ),
          decoration: const InputDecoration(hintText: 'File name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (newName.trim().isNotEmpty) {
                try {
                  final file = File(filePath);
                  final newPath = path.join(
                    path.dirname(filePath),
                    newName + path.extension(filePath),
                  );
                  await file.rename(newPath); // actually renames the file
                  setState(() {
                    if (folder != null) {
                      final index = folder.files.indexOf(filePath);
                      folder.files[index] = newPath;
                    } else {
                      final index = files.indexOf(filePath);
                      files[index] = newPath;
                    }
                    _saveData();
                  });
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to rename file: $e')),
                  );
                }
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addFile({StudyFolder? folder}) async {
    try {
      final XFile? result = await openFile(
        acceptedTypeGroups: [
          XTypeGroup(
            label: 'Documents',
            extensions: ['pdf', 'jpg', 'png', 'jpeg'],
          ),
        ],
      );
      if (result != null) {
        setState(() {
          if (folder != null) {
            folder.files.add(result.path);
          } else {
            files.add(result.path);
          }
          _saveData();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to pick file')));
    }
  }

  void _openFile(String filePath) => OpenFile.open(filePath);

  Future<void> _confirmDelete({
    required Function onConfirm,
    required String title,
  }) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete $title?'),
        content: const Text('Are you sure you want to delete this?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteFile(String filePath, {StudyFolder? folder}) {
    _confirmDelete(
      title: path.basename(filePath),
      onConfirm: () {
        setState(() {
          if (folder != null) {
            folder.files.remove(filePath);
          } else {
            files.remove(filePath);
          }
          _saveData();
        });
      },
    );
  }

  void _deleteFolder(StudyFolder folder) {
    _confirmDelete(
      title: folder.name,
      onConfirm: () {
        setState(() {
          folders.remove(folder);
          _saveData();
        });
      },
    );
  }

  void _openFolder(StudyFolder folder) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FolderContentsScreen(
          folder: folder,
          saveCallback: _saveData,
          deleteFile: _deleteFile,
          addFile: _addFile,
          deleteFolder: _deleteFolder,
          renameFile: _renameFile,
          renameFolder: _renameFolder,
        ),
      ),
    ).then((_) => setState(() {})); // refresh parent
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Files'),
        actions: [
          IconButton(
            onPressed: _addFolder,
            icon: const Icon(Icons.create_new_folder),
          ),
          IconButton(onPressed: () => _addFile(), icon: const Icon(Icons.add)),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: folders.length + files.length,
        itemBuilder: (context, index) {
          if (index < folders.length) {
            final folder = folders[index];
            return GestureDetector(
              onTap: () => _openFolder(folder),
              child: Card(
                elevation: 4,
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.folder,
                            size: 50,
                            color: Colors.blue,
                          ),
                          const SizedBox(height: 8),
                          Text(folder.name, textAlign: TextAlign.center),
                          const SizedBox(height: 4),
                          Text(
                            '${folder.files.length} files',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: PopupMenuButton(
                        icon: const Icon(Icons.more_vert),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'rename',
                            child: Text('Rename'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'rename') {
                            _renameFolder(folder);
                          } else if (value == 'delete') {
                            _deleteFolder(folder);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else {
            final filePath = files[index - folders.length];
            return GestureDetector(
              onTap: () => _openFile(filePath),
              child: Card(
                elevation: 4,
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.insert_drive_file,
                            size: 50,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            path.basename(filePath),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: PopupMenuButton(
                        icon: const Icon(Icons.more_vert),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'rename',
                            child: Text('Rename'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'rename') {
                            _renameFile(filePath);
                            
                          } else if (value == 'delete') {
                            _deleteFile(filePath);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }
}

// class FolderContentsScreen extends StatefulWidget {
//   final StudyFolder folder;
//   final Function saveCallback;
//   final Function deleteFile;
//   final Function addFile;
//   final Function deleteFolder;
//   final Function renameFile;
//   final Function renameFolder;

//   const FolderContentsScreen({
//     super.key,
//     required this.folder,
//     required this.saveCallback,
//     required this.deleteFile,
//     required this.addFile,
//     required this.deleteFolder,
//     required this.renameFile,
//     required this.renameFolder,
//   });

//   @override
//   State<FolderContentsScreen> createState() => _FolderContentsScreenState();
// }

// class _FolderContentsScreenState extends State<FolderContentsScreen> {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text(widget.folder.name)),
//       body: ListView(
//         children: [
//           ...widget.folder.files.map(
//             (f) => ListTile(
//               title: Text(path.basename(f)),
//               trailing: Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   IconButton(
//                     icon: const Icon(Icons.open_in_new),
//                     onPressed: () => OpenFile.open(f),
//                   ),
//                   PopupMenuButton(
//                     icon: const Icon(Icons.more_vert),
//                     itemBuilder: (_) => [
//                       const PopupMenuItem(
//                         value: 'rename',
//                         child: Text('Rename'),
//                       ),
//                       const PopupMenuItem(
//                         value: 'delete',
//                         child: Text('Delete'),
//                       ),
//                     ],
//                     onSelected: (value) {
//                       if (value == 'rename') {
//                         widget.renameFile(f, folder: widget.folder);
//                         setState(() {});
//                       } else if (value == 'delete') {
//                         widget.deleteFile(f, folder: widget.folder);
//                         setState(() {});
//                       }
//                     },
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           ListTile(
//             leading: const Icon(Icons.add),
//             title: const Text('Add file'),
//             onTap: () async {
//               await widget.addFile(folder: widget.folder);
//               setState(() {});
//             },
//           ),
//         ],
//       ),
//     );
//   }
// }
class FolderContentsScreen extends StatefulWidget {
  final StudyFolder folder;
  final Function saveCallback;
  final Function deleteFile;
  final Function addFile;
  final Function deleteFolder;
  final Function renameFile;
  final Function renameFolder;

  const FolderContentsScreen({
    super.key,
    required this.folder,
    required this.saveCallback,
    required this.deleteFile,
    required this.addFile,
    required this.deleteFolder,
    required this.renameFile,
    required this.renameFolder,
  });

  @override
  State<FolderContentsScreen> createState() => _FolderContentsScreenState();
}

class _FolderContentsScreenState extends State<FolderContentsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder.name),
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'rename', child: Text('Rename Folder')),
              const PopupMenuItem(value: 'delete', child: Text('Delete Folder')),
            ],
            onSelected: (value) async {
              if (value == 'rename') {
                await widget.renameFolder(widget.folder);
                setState(() {});
                await widget.saveCallback();
              } else if (value == 'delete') {
                await widget.deleteFolder(widget.folder);
                Navigator.pop(context); // close folder screen after deletion
              }
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          ...widget.folder.files.map(
            (f) => ListTile(
              title: Text(path.basename(f)),
              onTap: () => OpenFile.open(f), // open on single tap
              trailing: PopupMenuButton(
                icon: const Icon(Icons.more_vert),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'rename', child: Text('Rename')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
                onSelected: (value) async {
                  if (value == 'rename') {
                    await widget.renameFile(f, folder: widget.folder);
                    setState(() {});
                    await widget.saveCallback();
                  } else if (value == 'delete') {
                    await widget.deleteFile(f, folder: widget.folder);
                    setState(() {});
                    await widget.saveCallback();
                  }
                },
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Add file'),
            onTap: () async {
              await widget.addFile(folder: widget.folder);
              setState(() {});
              await widget.saveCallback();
            },
          ),
        ],
      ),
    );
  }
}
