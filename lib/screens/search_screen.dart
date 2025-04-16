import 'dart:async';
import 'dart:convert';
import 'package:DILGDOCS/Services/globals.dart';
import 'package:DILGDOCS/models/republic_acts.dart';
import 'package:DILGDOCS/screens/details.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:wave/wave.dart';
import 'package:wave/config.dart';
import 'package:DILGDOCS/utils/routes.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/draft_issuances.dart';
import '../models/joint_circulars.dart';
import '../models/latest_issuances.dart';
import '../models/legal_opinions.dart';
import '../models/memo_circulars.dart';
import '../models/presidential_directives.dart';
import 'sidebar.dart';

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  TextEditingController _searchController = TextEditingController();
  String searchInput = '';
  List<String> _recentSearches = [""];
  List<SearchResult> searchResults = [];
  List<MemoCircular> _memoCirculars = [];
  List<MemoCircular> get memoCirculars => _memoCirculars;
  List<PresidentialDirective> _presidentialDirectives = [];
  List<PresidentialDirective> get presidentialDirectives =>
      _presidentialDirectives;
  List<RepublicAct> _republicActs = [];
  List<RepublicAct> get republicActs => _republicActs;
  List<LegalOpinion> _legalOpinions = [];
  List<LegalOpinion> get legalOpinions => _legalOpinions;
  List<JointCircular> _jointCirculars = [];
  List<JointCircular> get jointCirculars => _jointCirculars;
  List<DraftIssuance> _draftIssuances = [];
  List<DraftIssuance> get draftIssuances => _draftIssuances;
  List<LatestIssuance> _latestIssuances = [];
  List<LatestIssuance> get latestIssuances => _latestIssuances;

  stt.SpeechToText speech = stt.SpeechToText();
  bool isListening = false;
  bool isModalOpen = false;
  bool isSearching = false;
  bool showNoMatchFound = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _initializeSpeechToText();
    fetchRepublicActs();
    fetchPresidentialCirculars();
    fetchMemoCirculars();
    fetchLegalOpinions();
    fetchLatestIssuances();
    fetchJointCirculars();
    fetchDraftIssuances();
  }

  void _initializeSpeechToText() async {
    var status = await Permission.microphone.status;
    print('Microphone Permission Status: $status');

    if (status.isGranted) {
      print('Speech recognition available');
      bool isAvailable = await speech.initialize(
        onError: (error) => print('Error during initialization: $error'),
      );

      if (isAvailable) {
        print('Speech recognition initialized successfully');
      } else {
        print('Speech recognition initialization failed');
      }
    } else {
      print('Microphone permission denied');
    }
  }

  void _startListening() {
    print('Start Listening');
    setState(() {
      isModalOpen = true;
    });
    if (speech.isAvailable) {
      if (!speech.isListening) {
        _showListeningDialog(context);
        speech.listen(
          onResult: (result) {
            if (result.finalResult) {
              String searchText = result.recognizedWords;
              _searchController.text = searchText;
              print('Search Text: $searchText');
              _handleSearch();
              Navigator.pop(context);
            }
          },
        );
      }
    } else {
      print('Speech recognition not available');
    }
  }

  void _stopListening() {
    if (isListening) {
      speech.stop();
      setState(() {
        isListening = false;
        isModalOpen = false;
      });
      Navigator.pop(context); // Dismiss the dialog when listening stops
    }
  }

  void _showListeningDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Listening..."),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                WaveWidget(
                  config: CustomConfig(
                    gradients: [
                      [Colors.blue, Colors.blueAccent],
                      [Colors.blueAccent, Colors.blue],
                    ],
                    durations: [1500, 1000],
                    heightPercentages: [0.25, 0.3],
                    blur: MaskFilter.blur(
                      BlurStyle.solid,
                      10,
                    ),
                    gradientBegin: Alignment.bottomLeft,
                    gradientEnd: Alignment.topRight,
                  ),
                  waveAmplitude: 1,
                  size: Size(300, 100),
                ),
                SizedBox(height: 16),
                // Text("Please speak your search query."),
              ],
            ),
          ),
        );
      },
    );
  }

  void _checkPermissions() async {
    var status = await Permission.microphone.status;

    if (!status.isGranted) {
      print('Requesting microphone permission...');
      await Permission.microphone.request();
      status = await Permission.microphone.status;

      if (status.isGranted) {
        print(
            'Microphone permission granted. Initializing speech recognition...');
        _initializeSpeechToText();
      } else {
        print('Microphone permission denied');
      }
    }
  }

  @override
  void dispose() {
    // Cancel any ongoing asynchronous operations here
    // For example, canceling network requests, timers, etc.
    super.dispose();
    _searchController.dispose();
    _stopListening();
  }

  Future<void> fetchDraftIssuances() async {
    final response = await http.get(
      Uri.parse('$baseURL/draft_issuances'),
      headers: {
        'Accept': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body)['drafts'];
      setState(() {
        _draftIssuances =
            data.map((item) => DraftIssuance.fromJson(item)).toList();
      });
    } else {
      // Handle error
      print('Failed to load Draft issuances');

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');
    }
  }

  Future<void> fetchJointCirculars() async {
    final response = await http.get(
      Uri.parse('$baseURL/joint_circulars'),
      headers: {
        'Accept': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body)['joints'];

      setState(() {
        _jointCirculars =
            data.map((item) => JointCircular.fromJson(item)).toList();
      });
    } else {
      // Handle error
      print('Failed to load latest issuances');
      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');
    }
  }

//Presidential Directives
  Future<void> fetchPresidentialCirculars() async {
    final response = await http.get(
      Uri.parse('$baseURL/presidential_directives'),
      headers: {
        'Accept': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic>? data = json.decode(response.body)['presidentials'];

      if (data != null) {
        print('Presidential Directives Data: $data');

        setState(() {
          _presidentialDirectives =
              data.map((item) => PresidentialDirective.fromJson(item)).toList();
        });
      } else {
        print('Presidential Directives Data is null');
      }
    } else {
      // Handle error
      print('Failed to load latest issuances');
      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');
    }
  }

// Republic Acts
  Future<void> fetchRepublicActs() async {
    final response = await http.get(
      Uri.parse('$baseURL/republic_acts'),
      headers: {
        'Accept': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body)['republics'];

      setState(() {
        _republicActs = data.map((item) => RepublicAct.fromJson(item)).toList();
      });
    } else {
      // Handle error
      print('Failed to load republic acts');
      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');
    }
  }

// Memo Circulars
  Future<void> fetchMemoCirculars() async {
    final response = await http.get(
      Uri.parse('$baseURL/memo_circulars'),
      headers: {
        'Accept': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body)['memos'];

      setState(() {
        _memoCirculars =
            data.map((item) => MemoCircular.fromJson(item)).toList();
      });
    } else {
      // Handle error
      print('Failed to load latest issuances');
      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');
    }
  }

  Future<void> fetchLegalOpinions() async {
    final response =
        await http.get(Uri.parse('$baseURL/legal_opinions'), headers: {
      'Accept': 'application/json',
    });

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body)['legals'];

      setState(() {
        _legalOpinions =
            data.map((item) => LegalOpinion.fromJson(item)).toList();
      });
    } else {
      print('Failed to load latest legal opinions');
      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');
    }
  }

  Future<void> fetchLatestIssuances() async {
    final response = await http.get(
      Uri.parse('$baseURL/latest_issuances'),
      headers: {
        'Accept': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body)['latests'];

      setState(() {
        _latestIssuances =
            data.map((item) => LatestIssuance.fromJson(item)).toList();
      });
    } else {
      print('Failed to load latest issuances');
      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');
    }
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.5),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.search),
                            onPressed: () {
                              _handleSearch();
                            },
                          ),
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Stack(
                                children: [
                                  TextField(
                                    controller: _searchController,
                                    decoration: InputDecoration(
                                      hintText: 'Search',
                                      border: InputBorder.none,
                                    ),
                                    onChanged: (value) {
                                      _debounce(() {
                                        _handleSearch();
                                      }, Duration(milliseconds: 500));
                                    },
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    top: 0,
                                    child: isListening
                                        ? WaveWidget(
                                            config: CustomConfig(
                                              gradients: [
                                                [Colors.red, Colors.redAccent],
                                                [Colors.redAccent, Colors.red],
                                              ],
                                              durations: [3500, 2000],
                                              heightPercentages: [0.25, 0.3],
                                              blur: MaskFilter.blur(
                                                BlurStyle.solid,
                                                10,
                                              ),
                                              gradientBegin:
                                                  Alignment.bottomLeft,
                                              gradientEnd: Alignment.topRight,
                                            ),
                                            waveAmplitude: 1,
                                            size: Size(50, double.infinity),
                                          )
                                        : SizedBox(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.mic),
                            color: isListening ? Colors.red : null,
                            onPressed:
                                isListening ? _stopListening : _startListening,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              _buildSearchResultsContainer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultsContainer() {
    if (isSearching) {
      return Center(
        child: CircularProgressIndicator(),
      );
    } else if (showNoMatchFound) {
      return Center(
        child: Text('No match found', style: TextStyle(fontFamily: 'Poppins')),
      );
    } else if (searchResults.isNotEmpty) {
      return SingleChildScrollView(
        child: Column(
          children: [
            _buildSearchResults(searchResults, searchInput),
            SizedBox(height: 20),
          ],
        ),
      );
    } else {
      return _buildRecentSearchesContainer();
    }
  }

  Widget _buildRecentSearchesContainer() {
    List<Map<String, dynamic>> containerInfo = [
      {
        'name': 'Latest Issuances',
        'route': Routes.latestIssuances,
        'color': Colors.blue,
        'icon': Icons.book
      },
      {
        'name': 'Joint Circulars',
        'route': Routes.jointCirculars,
        'color': Colors.red,
        'icon': Icons.compare_arrows
      },
      {
        'name': 'Memo Circulars',
        'route': Routes.memoCirculars,
        'color': Colors.green,
        'icon': Icons.note
      },
      {
        'name': 'Presidential Directives',
        'route': Routes.presidentialDirectives,
        'color': Colors.pink,
        'icon': Icons.account_balance
      },
      {
        'name': 'Draft Issuances',
        'route': Routes.draftIssuances,
        'color': Colors.purple,
        'icon': Icons.drafts
      },
      {
        'name': 'Republic Acts',
        'route': Routes.republicActs,
        'color': Colors.teal,
        'icon': Icons.gavel
      },
      {
        'name': 'Legal Opinions',
        'route': Routes.legalOpinions,
        'color': Colors.orange,
        'icon': Icons.library_add_check_outlined
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        isListening
            ? Container(
                margin: EdgeInsets.all(8),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    WaveWidget(
                      config: CustomConfig(
                        gradients: [
                          [Colors.red, Colors.redAccent],
                          [Colors.redAccent, Colors.red],
                        ],
                        durations: [3500, 2000],
                        heightPercentages: [0.25, 0.3],
                        blur: MaskFilter.blur(
                          BlurStyle.solid,
                          10,
                        ),
                        gradientBegin: Alignment.bottomLeft,
                        gradientEnd: Alignment.topRight,
                      ),
                      waveAmplitude: 1,
                      size: Size(50, double.infinity),
                    ),
                    SizedBox(width: 16),
                    Text(
                      'Listening...',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                          fontFamily: 'Poppins'),
                    ),
                  ],
                ),
              )
            : SizedBox.shrink(),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Browse All',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins'),
          ),
        ),
        GridView.count(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          children: List.generate(containerInfo.length, (index) {
            Map<String, dynamic> item = containerInfo[index];
            return Card(
              elevation: 3,
              margin: EdgeInsets.all(8),
              child: InkWell(
                onTap: () {
                  _handleContainerTap(context, item['route']);
                },
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item['icon'],
                          color: Colors.white,
                        ),
                        SizedBox(height: 8),
                        Text(
                          item['name'],
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'Poppins'),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              color: item['color'],
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSearchResults(
      List<SearchResult> searchResults, String searchInput) {
    if (searchInput.isEmpty) {
      return SizedBox.shrink();
    }

    return searchResults.isNotEmpty
        ? SingleChildScrollView(
            child: Column(
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: searchResults.length,
                  itemBuilder: (context, index) {
                    final SearchResult result = searchResults[index];
                    debugPrint(
                        'Result $index - Type: ${result.type}, ExtractedTexts: ${result.extractedTexts}'); // Debug print

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetailsScreen(
                              searchResult: result,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 8),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.5),
                              spreadRadius: 2,
                              blurRadius: 5,
                              offset: Offset(0, 3),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            Text.rich(
                              highlightTextWithOriginalTitle(
                                text: result.title,
                                highlight: searchInput,
                                limitLines: false,
                                baseStyle: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                            ),

                            // Extracted Texts - Improved version
                            if (result.type == 'Legal Opinions' &&
                                result.extractedTexts != null)
                              Builder(
                                builder: (context) {
                                  final extracted =
                                      result.extractedTexts!.trim();
                                  if (extracted.isEmpty)
                                    return SizedBox.shrink();

                                  final highlighted =
                                      highlightTextWithOriginalTitle(
                                    text: extracted,
                                    highlight: searchInput,
                                    limitLines: true,
                                    baseStyle: TextStyle(
                                      color: Colors.grey[800],
                                      fontSize: 14,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    highlightStyle: TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                      backgroundColor:
                                          Colors.yellow.withOpacity(0.3),
                                    ),
                                  );

                                  return Padding(
                                    padding: EdgeInsets.only(top: 8, bottom: 4),
                                    child: RichText(
                                      text: highlighted,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                },
                              ),

                            // Reference
                            Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'Ref #: ${result.reference}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),

                            // Type
                            Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                'Type: ${result.type}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          )
        : Center(child: Text('No results found'));
  }

  TextSpan highlightTextWithOriginalTitle({
    required String text,
    required String highlight,
    bool limitLines = false,
    int maxLines = 3,
    TextStyle? baseStyle,
    TextStyle? highlightStyle,
  }) {
    if (highlight.isEmpty) {
      return TextSpan(
        text: text,
        style: baseStyle ?? TextStyle(color: Colors.black),
      );
    }

    // For non-line-limited text (like titles)
    if (!limitLines) {
      List<TextSpan> spans = [];
      int prevIndex = 0;
      int index = text.toLowerCase().indexOf(highlight.toLowerCase());

      while (index != -1) {
        spans.add(TextSpan(
          text: text.substring(prevIndex, index),
          style: baseStyle,
        ));
        spans.add(TextSpan(
          text: text.substring(index, index + highlight.length),
          style: highlightStyle ?? TextStyle(color: Colors.blue),
        ));
        prevIndex = index + highlight.length;
        index = text.toLowerCase().indexOf(highlight.toLowerCase(), prevIndex);
      }

      spans.add(TextSpan(
        text: text.substring(prevIndex),
        style: baseStyle,
      ));

      return TextSpan(children: spans);
    }

    // For line-limited text (like extracted texts)
    List<String> lines = text.split('\n');
    List<TextSpan> spans = [];
    int matchedLines = 0;
    bool hasMoreMatches = false;

    for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      String line = lines[lineIndex];
      List<TextSpan> lineSpans = [];
      bool lineHasMatch = false;

      int index = line.toLowerCase().indexOf(highlight.toLowerCase());
      if (index != -1) {
        lineHasMatch = true;
        matchedLines++;
      }

      if (lineHasMatch || (matchedLines > 0 && matchedLines <= maxLines)) {
        int prevIndex = 0;
        index = line.toLowerCase().indexOf(highlight.toLowerCase());

        while (index != -1) {
          lineSpans.add(TextSpan(
            text: line.substring(prevIndex, index),
            style: baseStyle,
          ));
          lineSpans.add(TextSpan(
            text: line.substring(index, index + highlight.length),
            style: highlightStyle ?? TextStyle(color: Colors.blue),
          ));
          prevIndex = index + highlight.length;
          index =
              line.toLowerCase().indexOf(highlight.toLowerCase(), prevIndex);
        }

        lineSpans.add(TextSpan(
          text: line.substring(prevIndex),
          style: baseStyle,
        ));

        if (lineIndex < lines.length - 1) {
          lineSpans.add(TextSpan(text: '\n'));
        }

        spans.addAll(lineSpans);
      }

      if (lineHasMatch && matchedLines > maxLines) {
        hasMoreMatches = true;
        break;
      }
    }

    if (hasMoreMatches || matchedLines > maxLines) {
      spans.add(TextSpan(
        text: '...',
        style: baseStyle,
      ));
    }

    return TextSpan(children: spans);
  }

  void _handleSearch() async {
    String searchInput = _searchController.text.toLowerCase();

    print('Search Input: $searchInput');
    print('Searching: ${_searchController.text}');

    if (searchInput.length < 3) {
      setState(() {
        this.searchResults = [];
        this.searchInput = '';
        showNoMatchFound = false;
      });
      return;
    }

    if (searchInput.isNotEmpty) {
      setState(() {
        isSearching = true;
        showNoMatchFound = false;
      });

      List<dynamic> allData = [
        ..._memoCirculars,
        ..._presidentialDirectives,
        ..._republicActs,
        ..._legalOpinions,
        ..._jointCirculars,
        ..._draftIssuances,
        ..._latestIssuances,
      ];

      List<SearchResult> searchResults = allData
          .where((data) {
            if (data is MemoCircular ||
                data is DraftIssuance ||
                data is LatestIssuance) {
              return data.issuance.title.toLowerCase().contains(searchInput) ||
                  (data.issuance.keyword?.toLowerCase().contains(searchInput) ??
                      false);
            } else if (data is PresidentialDirective) {
              return data.title.toLowerCase().contains(searchInput) ||
                  data.reference.toLowerCase().contains(searchInput);
            } else if (data is RepublicAct) {
              return data.title.toLowerCase().contains(searchInput) ||
                  data.reference.toLowerCase().contains(searchInput);
            } else if (data is LegalOpinion) {
              return data.title.toLowerCase().contains(searchInput) ||
                  data.reference.toLowerCase().contains(searchInput) ||
                  (data.extractedTexts?.toLowerCase().contains(searchInput) ??
                      false);
            } else if (data is JointCircular) {
              return data.title.toLowerCase().contains(searchInput) ||
                  data.reference.toLowerCase().contains(searchInput);
            }
            return false;
          })
          .map((data) {
            if (data is MemoCircular) {
              return SearchResult(
                data.issuance.title,
                data.issuance.urlLink,
                'Memo Circular',
                data.issuance.referenceNo,
              );
            } else if (data is DraftIssuance) {
              return SearchResult(
                data.issuance.title,
                data.issuance.urlLink,
                'Draft Issuance',
                data.issuance.referenceNo,
              );
            } else if (data is LatestIssuance) {
              return SearchResult(
                data.issuance.title,
                data.issuance.urlLink,
                'Latest Issuance',
                data.issuance.referenceNo,
              );
            } else if (data is PresidentialDirective) {
              return SearchResult(
                data.title,
                data.link,
                data.type,
                data.reference,
              );
            } else if (data is RepublicAct) {
              return SearchResult(
                data.title,
                data.link,
                'Republic Act',
                data.reference,
              );
            } else if (data is LegalOpinion) {
              return SearchResult(
                data.title,
                data.link,
                'Legal Opinions',
                data.reference,
                data.extractedTexts,
              );
            } else if (data is JointCircular) {
              return SearchResult(
                data.title,
                data.link,
                'Joint Circular',
                data.reference,
              );
            }
            return SearchResult('', '', '', '');
          })
          .where((result) => result.title.isNotEmpty)
          .toList();

      if (searchResults.isEmpty) {
        try {
          final Map<String, String> queryParams = {
            'search': searchInput,
            'page': '1',
            'per_page': '50',
          };

          final uri = Uri.parse('$baseURL/legal_opinions').replace(
            queryParameters: queryParams,
          );

          final response = await http.get(
            uri,
            headers: {'Accept': 'application/json'},
          );

          if (response.statusCode == 200) {
            final responseData = json.decode(response.body);
            final List<dynamic> data = responseData['legals'];

            searchResults = data
                .map((item) => SearchResult(
                      item['title'],
                      item['link'],
                      'Legal Opinions',
                      item['reference'] ?? '',
                      item['extracted_texts'],
                    ))
                .toList();
          }
        } catch (error) {
          print('Error fetching legal opinions: $error');
        }
      }

      setState(() {
        this.searchResults = searchResults;
        this.searchInput = searchInput;
        isSearching = false;
        showNoMatchFound = searchResults.isEmpty;
      });
    } else {
      setState(() {
        this.searchResults = [];
        this.searchInput = '';
        showNoMatchFound = false;
      });
    }
  }

  void _debounce(VoidCallback callback, Duration duration) {
    if (_debounceTimer != null) {
      _debounceTimer!.cancel();
    }
    _debounceTimer = Timer(duration, callback);
  }

  // Method to handle the tapped recent search item
  void _handleRecentSearchTap(String value) {
    setState(() {
      _recentSearches.remove(value);
      _recentSearches.insert(0, value);
    });
  }

  void _handleContainerTap(BuildContext context, String route) {
    Navigator.pushNamed(context, route);
  }

  void _navigateToSelectedPage(BuildContext context, int index) {}
}

class SearchResult {
  final String title;
  final String pdfUrl;
  final String type;
  final String reference;
  final String? extractedTexts;

  SearchResult(this.title, this.pdfUrl, this.type, this.reference,
      [this.extractedTexts]);
}
