class StudyFile {
  String name;
  String path; // local file path

  StudyFile({required this.name, required this.path});

  Map<String, dynamic> toJson() => {'name': name, 'path': path};

  factory StudyFile.fromJson(Map<String, dynamic> json) =>
      StudyFile(name: json['name'], path: json['path']);
}
