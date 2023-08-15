import 'dart:developer';


class PhraseLoader {
  static const defaultSplitRegex = r"(\r\n)*@@@(\r\n)+";


  static List<Phrase> loadFrom(String data,
      {String splitRegex = defaultSplitRegex}) {
    Phrase.counter = 0;
    final list = List<Phrase>.empty(growable: true);

    for (final ment in data.split(RegExp(splitRegex))) {
      if (ment.isEmpty) continue;
      list.add(Phrase(ment));
    }

    for (final phrase in list) {
      log("phrase ${phrase.num}:\n${phrase.msg}");
    }
    return list;
  }
}

class Phrase {
  static int counter = 0;
  final num = counter++;
  final String msg;

  Phrase(this.msg);

  late final length = msg.length;
  late final linesCount = msg.split(RegExp('\r\n')).length - 1;
  late final summary = "${msg.replaceAll("\r\n", " ").substring(0, 45)} ...";
}
