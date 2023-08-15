import 'dart:convert' show utf8;
import 'dart:math';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/docs/v1.dart' as docs;
import 'package:googleapis/drive/v2.dart';
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
      title: '리뷰 멘트 머신',
      theme: ThemeData.dark().copyWith(
        appBarTheme: const AppBarTheme(
          color: primaryColor,
        ),
        colorScheme: const ColorScheme.dark(
          surface: Color(0xEE000000),
          primary: primaryColor,
        ),
      ),
      home: const MainPage(title: '리뷰 멘트 머신'),
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

  String _splitRegex = PhraseLoader.defaultSplitRegex;

  GoogleDocInfo? _gdocInfo;

  List<Phrase> _phrases = List.empty(growable: true);
  int _phrasesCount = 0;

  Phrase? _currentPhrase;
  int _currentPhraseIdx = 0;
  bool _drawOnCopy = true;
  bool _copied = false;

  int _previousIndex = 0;
  int _drawCount = 0;
  int _copyCount = 0;

  final _textButtonStyle = ButtonStyle(
      backgroundColor: MaterialStateProperty.all(primaryColor),
      foregroundColor: MaterialStateProperty.all(Colors.white));

  void _draw() {
    final previous = _currentPhraseIdx;
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
      _previousIndex = previous;
      _drawCount += 1;
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
      final data = PhraseLoader.loadFrom(string, splitRegex: _splitRegex);
      setState(() {
        _currentState = _State.REVIEWING_DATA;
        _phrases = data;
        _phrasesCount = data.length;
      });
    }
  }

  void _reloadFromGdoc() async {
    final gd = _gdocInfo;

    if (gd != null) {
      setState(() {
        _currentState = _State.LOADING_DATA;
      });

      final string = await gd.read();
      final regex = _splitRegex;
      final newList = PhraseLoader.loadFrom(string, splitRegex: regex);
      setState(() {
        _phrases = newList;
        _phrasesCount = newList.length;
        _currentState = _State.REVIEWING_DATA;
      });
    }
  }

  Future<GoogleDriveInfo> _fetchGoogleDrive() async {
    final signIn = GoogleSignIn(
      scopes: <String>[
        'https://www.googleapis.com/auth/documents.readonly',
        'https://www.googleapis.com/auth/drive.readonly'
      ],
    );
    final account = await signIn.signInSilently() ?? await signIn.signIn();
    final client = await signIn.authenticatedClient();
    final driveApi = DriveApi(client!);
    final docsApi = docs.DocsApi(client);
    final files = (await driveApi.files.list(includeItemsFromAllDrives: false, includeTeamDriveItems: false)).items!;
    return GoogleDriveInfo(driveApi, docsApi, account!, files);
  }

  void _openGoogleDocSelector() async {
    Navigator.push(context, MaterialPageRoute(builder: (ctx) {
      return FutureBuilder(
        future: _fetchGoogleDrive(),
        builder: (ctx, snapshot) {
          Widget body;
          if (!snapshot.hasData) {
            body = Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            body = Center(child: Text("err!"));
          } else {
            var data = snapshot.requireData;
            final files = data.files;
            body = ListView.separated(
                itemCount: files.length,
                separatorBuilder: (ctx, idx) => const Divider(),
                itemBuilder: (ctx, idx) {
                  final file = files[idx];
                  return ListTile(
                    title: Text(file.title ?? "이름 없는 파일"),
                    subtitle: Text(file.id ?? "#"),
                    onTap: () async {
                      final gd = GoogleDocInfo(data.driveApi, data.docsApi, data.account, data.files, file.id!);
                      _gdocInfo = gd;
                      _reloadFromGdoc();
                      Navigator.pop(ctx);
                    },
                  );
                });
          }
          return Scaffold(
            appBar: AppBar(),
            body: body,
          );
        },
      );
    }));
  }

  @override
  Widget build(BuildContext context) {
    final drawButton = FloatingActionButton(
      onPressed: _draw,
      tooltip: '새 멘트',
      child: const Icon(Icons.refresh),
    );

    late final Widget page;

    final fileSelectorBtn = TextButton(
      style: _textButtonStyle.copyWith(backgroundColor: MaterialStatePropertyAll(Colors.amber)),
      child: const Text('파일 다시 선택'),
      onPressed: _openFileSelector,
    );

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
                  SizedBox(
                    height: 50,
                    width: 400,
                    child: TextButton(
                      style: _textButtonStyle.copyWith(backgroundColor: MaterialStatePropertyAll(Colors.blueAccent)),
                      onPressed: _openGoogleDocSelector,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.document_scanner),
                          const Text('Google Docs에서 가져오기'),
                        ],
                      ),
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
                    final regex = v.isEmpty ? PhraseLoader.defaultSplitRegex : v;
                    _splitRegex = regex;
                    Fluttertoast.showToast(msg: "Custom Regex Set : $regex");
                  },
                  decoration: const InputDecoration(
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
                    child: fileSelectorBtn,
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
      case _State.LOADING_DATA:
        page = Center(
          child: CircularProgressIndicator(),
        );
        break;

      case _State.PHRASE:
        final phrase = _currentPhrase;

        if (phrase == null) {
          page = drawButton;
          break;
        }
        final msg = phrase.msg;

        final explorerBtn = TextButton(
          style: _textButtonStyle,
          onPressed: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (ctx) {
                    return Scaffold(
                      appBar: AppBar(
                        title: Text('$_phrasesCount개의 멘트가 로드되었습니다. ( 클릭하여 클립보드에 복사 )'),
                      ),
                      body: ListView.separated(
                        itemCount: _phrasesCount,
                        itemBuilder: (ctx2, idx) {
                          final p = _phrases[idx];
                          return ListTile(
                            leading: Text(
                              p.num.toString(),
                              style: Theme.of(ctx2).textTheme.titleLarge,
                            ),
                            title: Text(p.msg),
                            onTap: () {
                              _copyToClipboard(p.msg, "${p.num}번 멘트가 클립보드에 복사되었습니다.");
                            },
                          );
                        },
                        separatorBuilder: (BuildContext context, int index) => const Divider(
                          thickness: 2,
                          indent: 1.0,
                          color: primaryColor,
                        ),
                      ),
                    );
                  },
                ));
          },
          child: Text('멘트 탐색기'),
        );

        page = Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    const Text("복사 후 즉시 새로고침"),
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
                                style: TextStyle(color: _copied ? primaryColor : Colors.amber),
                              ),
                            ],
                          ),
                        ),
                        onTap: () {
                          _copyToClipboard(msg, "${phrase.num}번 멘트가 클립보드에 복사되었습니다.");
                          setState(() {
                            _copyCount += 1;
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
                      "현재 멘트 인덱스 : ${phrase.num} / 길이 : ${phrase.length} / 줄바꿈 : ${phrase.linesCount} ${_copied ? " (복사됨)" : ""}",
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 5),
                    Text("이전 멘트 인덱스 : $_previousIndex")
                  ],
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('새로고침 수 : $_drawCount / 복사 수 : $_copyCount'),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    fileSelectorBtn,
                    const SizedBox(width: 10),
                    explorerBtn,
                  ],
                ),
              ],
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

  void _copyToClipboard(String clipboard, String message) {
    Clipboard.setData(ClipboardData(text: clipboard));
    Fluttertoast.showToast(
        msg: message, toastLength: Toast.LENGTH_SHORT, gravity: ToastGravity.TOP_RIGHT, webPosition: 'right');
  }
}

enum _State {
  SELECTING_FILE,
  REVIEWING_DATA,
  LOADING_DATA,
  READY,
  PHRASE,
}

class GoogleDocInfo extends GoogleDriveInfo {
  final String fileID;

  GoogleDocInfo(super.driveApi, super.docsApi, super.account, super.files, this.fileID);

  Future<String> read() async {
    final media = await driveApi.files.export(
      fileID,
      'text/plain',
      downloadOptions: DownloadOptions.fullMedia,
    );

    final lists = await media!.stream.toList();
    final lines = List<String>.empty(growable: true);
    for (var value in lists) {
      lines.add(utf8.decode(value));
    }
    return lines.join();
  }
}

class GoogleDriveInfo {
  final DriveApi driveApi;
  final docs.DocsApi docsApi;
  final GoogleSignInAccount account;
  final List<File> files;

  GoogleDriveInfo(this.driveApi, this.docsApi, this.account, this.files);
}
