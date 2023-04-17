import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pod_player/pod_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;
import 'package:universal_html/html.dart' as phtml;
import 'package:flutter/foundation.dart' show kIsWeb;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reddit Reader',
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
      ),
      home: const MyHomePage(title: 'Reddit Reader'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<dynamic> feedList = [];
  List<dynamic> favorites = [];
  final String baseUrl = "https://www.reddit.com";
  late String path;
  late String subReddit;
  late String after;
  final searchController = TextEditingController();
  final scrollController = ScrollController();
  final focusNode = FocusNode();
  final double maxWidth = 768.0;

  @override
  void initState() {
    super.initState();
    retrieveFavorites();
    reset();
  }

  void reset() {
    path = '/best.json';
    subReddit = 'best';
    fetchData();
  }

  Future<void> fetchData({bool next = false}) async {
    try {
      String url = '$baseUrl$path';
      if (next) {
        url += '?after=$after';
      }
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        setState(() {
          if (next) {
            feedList.addAll(jsonData['data']['children']);
          } else {
            feedList = jsonData['data']['children'];
          }
          after = jsonData['data']['after'];
        });
      } else {
        // mostra erro
      }
    } on Exception catch (e) {
      // TODO
    }
  }

  Widget getPostImage(BuildContext context, dynamic item) {
    String tbUrl = "";
    if (item.containsKey('data') && item['data'].containsKey('thumbnail')) {
      tbUrl = item['data']['thumbnail'];
    }

    return GestureDetector(
      onTap: () {
        String imgUrl = "";
        if (item.containsKey('data') && item['data'].containsKey('preview')) {
          if (item['data']['preview'].containsKey('reddit_video_preview')) {
            if (item['data']['preview']['reddit_video_preview']
                .containsKey('fallback_url')) {
              imgUrl = item['data']['preview']['reddit_video_preview']
                  ['fallback_url'];
              showVideo(context, imgUrl);
              // _launchUrl(
              //   Uri.parse(imgUrl),
              // );
            }
          } else if (item['data']['media'] != null &&
              item['data']['media'].containsKey('reddit_video')) {
            imgUrl = item['data']['media']['reddit_video']['fallback_url'];
            showVideo(context, imgUrl);
          } else if (item['data']['preview'].containsKey('images')) {
            imgUrl = item['data']['preview']['images'][0]['source']['url']
                .replaceAll('&amp;', '&');
            if (imgUrl.contains('.gifv')) {
              showVideo(context, imgUrl);
              // _launchUrl(
              //   Uri.parse(imgUrl),
              // );
            } else {
              showImage(context, imgUrl);
            }
          }
        }
        // if (imgUrl != "") {
        //   _launchUrl(
        //     Uri.parse(imgUrl),
        //   );
        // }
      },
      child: tbUrl.contains('http')
          ? Image.network(tbUrl.replaceAll('&amp;', '&'))
          : const Icon(
              Icons.image,
              size: 42,
            ),
    );
  }

  void showVideo(BuildContext context, String vUrl) {
    showDialog(
      context: context,
      builder: (context) {
        PodPlayerController vController = PodPlayerController(
          playVideoFrom: PlayVideoFrom.network(
            vUrl,
          ),
        )..initialise();
        return AlertDialog(
          backgroundColor: const Color.fromARGB(255, 107, 105, 105),
          content: Container(
            color: const Color.fromARGB(255, 107, 105, 105),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: PodVideoPlayer(controller: vController),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              onPressed: () =>
                  kIsWeb ? _downloadImageWeb(vUrl) : _downloadImageMobile(vUrl),
              icon: const Icon(Icons.download),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            )
          ],
        );
      },
    );
  }

  Future<Int8List> readNetworkImage(String imageUrl) async {
    final ByteData data =
        await NetworkAssetBundle(Uri.parse(imageUrl)).load(imageUrl);
    final Int8List bytes = data.buffer.asInt8List();
    return bytes;
  }

  Future<void> _downloadImageWeb(String url) async {
    final anchor = phtml.AnchorElement(href: url);
    anchor.download = '';
    phtml.document.body!.append(anchor);
    anchor.click();
    await Future.delayed(const Duration(milliseconds: 100));
    anchor.remove();
  }

  Future<void> _downloadImageMobile(String url) async {
    final uri = Uri.parse(url);
    final response = await http.get(uri);
    final bytes = response.bodyBytes;
    final downloadFolder = await getExternalStorageDirectory();
    final filePath =
        '${downloadFolder?.path}/${p.basename(uri.pathSegments.last)}';
    final file = File(filePath);
    await file.writeAsBytes(bytes);
  }

  void showImage(BuildContext context, String iUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color.fromARGB(255, 107, 105, 105),
          content: Container(
            color: const Color.fromARGB(255, 107, 105, 105),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: InteractiveViewer(
                    maxScale: double.infinity,
                    child: Image.network(
                      iUrl,
                      fit: BoxFit.fitWidth,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              onPressed: () =>
                  kIsWeb ? _downloadImageWeb(iUrl) : _downloadImageMobile(iUrl),
              icon: const Icon(Icons.download),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        );
      },
    );
  }

  Future<void> _launchUrl(Uri url) async {
    if (!await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    )) {
      throw Exception('Não foi possível abrir $url');
    }
  }

  void saveFavorites() async {
    setState(() {
      if (favorites.contains(subReddit)) {
        favorites.remove(subReddit);
      } else {
        favorites.add(subReddit);
      }
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('favorites', jsonEncode(favorites));
  }

  void retrieveFavorites() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? fav = prefs.getString('favorites');
    if (fav != null) {
      setState(() {
        favorites = jsonDecode(fav);
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    searchController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    scrollController.addListener(
      () {
        if (scrollController.position.pixels ==
            scrollController.position.maxScrollExtent) {
          fetchData(next: true);
        }
      },
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SafeArea(
        child: Container(
          color: Colors.black,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(8.0),
              color: const Color.fromARGB(255, 107, 105, 105),
              width: MediaQuery.of(context).size.width > 600
                  ? maxWidth
                  : MediaQuery.of(context).size.width,
              child: Column(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      focusNode: focusNode,
                      onEditingComplete: () {
                        focusNode.unfocus();
                      },
                      decoration: InputDecoration(
                        hintText: "Pesquisar",
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () {
                            focusNode.unfocus();
                            if (searchController.text
                                .startsWith(RegExp(r'[a-z]\/'))) {
                              path = '/${searchController.text}.json';
                            } else {
                              path = '/search.json?q=${searchController.text}';
                            }
                            scrollController.animateTo(
                              0.0,
                              curve: Curves.easeOut,
                              duration: const Duration(milliseconds: 300),
                            );
                            fetchData();
                            searchController.clear();
                          },
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            path = '/best.json';
                            subReddit = 'best';
                            fetchData();
                            scrollController.animateTo(
                              0.0,
                              curve: Curves.easeOut,
                              duration: const Duration(milliseconds: 300),
                            );
                          },
                          child: const Text('Best'),
                        ),
                        Row(
                          children: [
                            Text(subReddit),
                            IconButton(
                              onPressed: () {
                                saveFavorites();
                              },
                              icon: favorites.contains(subReddit)
                                  ? const Icon(Icons.favorite_outlined)
                                  : const Icon(Icons.favorite_border),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 9,
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: feedList.length,
                      separatorBuilder: (context, index) => const SizedBox(
                        height: 4.0,
                      ),
                      itemBuilder: (context, index) {
                        var item = feedList[index];

                        return Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(
                              10.0,
                            ),
                            border: Border.all(
                              color: Colors.black38,
                            ),
                          ),
                          constraints: const BoxConstraints(
                            minHeight: 80.0,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      _launchUrl(
                                        Uri.parse(
                                            "${item['data']['url_overridden_by_dest']}"),
                                      );
                                    },
                                    icon: const Icon(Icons.launch),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      _launchUrl(
                                        Uri.parse(
                                            "$baseUrl${item['data']['permalink']}"),
                                      );
                                    },
                                    icon: const Icon(Icons.reddit),
                                  ),
                                ],
                              ),
                              Text(item['data']['title']),
                              Text(item['data']['selftext']),
                              // Text(
                              //   const JsonEncoder.withIndent('        ')
                              //       .convert(
                              //     item['data'],
                              //   ),
                              // ),
                              getPostImage(context, item),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    path =
                                        '/${item['data']['subreddit_name_prefixed']}.json';
                                    subReddit =
                                        item['data']['subreddit_name_prefixed'];
                                    fetchData();
                                    scrollController.animateTo(
                                      0.0,
                                      curve: Curves.easeOut,
                                      duration:
                                          const Duration(milliseconds: 300),
                                    );
                                  });
                                },
                                child: Text(
                                  item['data']['subreddit_name_prefixed'],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      drawer: Drawer(
        child: Center(
          child: Container(
            color: const Color.fromARGB(255, 107, 105, 105),
            child: Column(
              children: [
                const DrawerHeader(
                  decoration: BoxDecoration(
                    color: Colors.deepOrange,
                  ),
                  child: Center(
                    child: Text(
                      'Favoritos',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: favorites.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Center(
                          child: Text(favorites[index]),
                        ),
                        onTap: () {
                          subReddit = favorites[index];
                          path = '/${favorites[index]}.json';
                          fetchData();
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
