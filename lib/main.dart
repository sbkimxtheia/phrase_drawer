import 'dart:convert' show utf8;
import 'dart:io';
import 'dart:js_interop';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:phrase_drawer/phrase_loader.dart';

void main() {
  runApp(const PhraseDrawerApp());
}

const primaryColor = Color(0xff48d1cc);

class PhraseDrawerApp extends StatelessWidget {
  const PhraseDrawerApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '리뷰 멘트 가챠 머신',
      theme: ThemeData.dark().copyWith(
        appBarTheme: const AppBarTheme(
          color: primaryColor,
        ),
        colorScheme: const ColorScheme.dark(
          surface: Color(0xEE000000),
          primary: primaryColor,
        ),
      ),
      home: const MainPage(title: '멘트 생성기'),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key, required this.title});

  final String title;

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  _State _currentState = _State.SELECTING_FILE;

  String _spligRegex = PhraseLoader.defaultSplitRegex;
  List<Phrase> _phrases = List.empty(growable: true);
  int _phrasesCount = 0;

  Phrase? _currentPhrase;
  int _currentPhraseIdx = 0;
  bool _drawOnCopy = true;
  bool _copied = false;

  final _textButtonStyle = ButtonStyle(
      backgroundColor: MaterialStateProperty.all(primaryColor),
      foregroundColor: MaterialStateProperty.all(Colors.white));

  void _draw() {
    int idx;
    if (_phrasesCount <= 1) {
      idx = 0;
    } else {
      idx = Random().nextInt(_phrasesCount);
      while (idx == _currentPhraseIdx) {
        idx = Random().nextInt(_phrasesCount);
      }
    }

    _currentPhraseIdx = idx;
    final newPhrase = _phrases[idx];

    setState(() {
      _copied = false;
      _currentPhrase = newPhrase;
    });
  }

  void _openFileSelector() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      dialogTitle: "데이터 파일 선택",
      allowedExtensions: ["txt"],
    );

    if (result != null) {
      final string = utf8.decode(result.files.single.bytes!);
      final data = PhraseLoader.loadFrom(string, splitRegex: _spligRegex);
      setState(() {
        _currentState = _State.REVIEWING_DATA;
        _phrases = data;
        _phrasesCount = data.length;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final drawButton = FloatingActionButton(
      onPressed: _draw,
      tooltip: '새 멘트',
      child: const Icon(Icons.refresh),
    );

    late final Widget page;

    switch (_currentState) {
      // region Select
      case _State.SELECTING_FILE:
        page = Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 50,
                    width: 400,
                    child: TextButton(
                      style: _textButtonStyle,
                      onPressed: _openFileSelector,
                      child: const Text('멘트 데이터 파일 선택'),
                    ),
                  ),
                  SizedBox(height: 10),
                  const Text('UTF-8 형식으로 저장된 Plain Text 파일 사용 권장'),
                ],
              ),

              // Settings
              SizedBox(
                width: 200,
                child: TextField(
                  onSubmitted: (v) {
                    final regex =
                        v.isEmpty ? PhraseLoader.defaultSplitRegex : v;
                    _spligRegex = regex;
                    Fluttertoast.showToast(msg: "Custom Regex Set : $regex");
                  },
                  decoration: InputDecoration(
                    helperText: "사용자 지정 스플리터 정규식",
                    hintText: PhraseLoader.defaultSplitRegex,
                  ),
                ),
              )
            ],
          ),
        );
        break;
      // endregion

      // Review
      case _State.REVIEWING_DATA:
        page = Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("로드된 멘트 : $_phrasesCount개"),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    height: 40,
                    child: TextButton(
                      style: _textButtonStyle.copyWith(
                          backgroundColor:
                              MaterialStatePropertyAll(Colors.amber)),
                      child: const Text('파일 다시 선택'),
                      onPressed: _openFileSelector,
                    ),
                  ),
                  SizedBox(width: 20),
                  SizedBox(
                    width: 200,
                    height: 40,
                    child: TextButton(
                      style: _textButtonStyle,
                      child: const Text('진행'),
                      onPressed: () {
                        setState(() {
                          _draw();
                          _currentState = _State.PHRASE;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('UTF-8 형식으로 저장된 Plain Text 파일 사용 권장'),
            ],
          ),
        );
        break;

      // endregion
      case _State.PHRASE:
        final phrase = _currentPhrase;

        if (phrase == null) {
          page = drawButton;
          break;
        }
        final msg = phrase.msg;
        page = Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    const Text("복사 후 새 멘트 즉시 생성"),
                    Switch(
                      value: _drawOnCopy,
                      onChanged: (v) => setState(() => _drawOnCopy = v),
                    ),
                  ],
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Card(
                      color: Colors.black87,
                      child: InkWell(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg,
                                style: TextStyle(
                                    color:
                                        _copied ? primaryColor : Colors.amber),
                              ),
                            ],
                          ),
                        ),
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: phrase.msg));
                          Fluttertoast.showToast(
                            msg: "${phrase.num}번 멘트가 클립보드에 복사되었습니다.",
                            toastLength: Toast.LENGTH_LONG,
                            gravity: ToastGravity.TOP,
                          );

                          setState(() {
                            _copied = true;
                          });

                          if (_drawOnCopy) {
                            _draw();
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "멘트 인덱스 : ${phrase.num}, 길이 : ${phrase.length}, 줄바꿈 : ${phrase.lines} ${_copied ? " (복사됨)" : ""}",
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

        break;
      case _State.READY:
        page = Text("hello..?");
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: page,
      ),
      floatingActionButton: drawButton,
    );
  }
}

enum _State {
  SELECTING_FILE,
  REVIEWING_DATA,
  READY,
  PHRASE,
}
