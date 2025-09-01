class StudyFolder {
  String name;
  List<String> files; // store file paths

  StudyFolder({required this.name, required this.files});

  Map<String, dynamic> toJson() => {'name': name, 'files': files};

  factory StudyFolder.fromJson(Map<String, dynamic> json) =>
      StudyFolder(name: json['name'], files: List<String>.from(json['files']));
}
