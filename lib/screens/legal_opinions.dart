import 'dart:async';
import 'dart:convert';
import 'package:DILGDOCS/Services/globals.dart';
import 'package:DILGDOCS/models/legal_opinions.dart';
import 'package:DILGDOCS/screens/file_utils.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'details_screen.dart';
import 'package:http/http.dart' as http;

class LegalOpinions extends StatefulWidget {
  @override
  _LegalOpinionsState createState() => _LegalOpinionsState();
}

class _LegalOpinionsState extends State<LegalOpinions>
    with SingleTickerProviderStateMixin {
  TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  List<LegalOpinion> _legalOpinions = [];
  List<LegalOpinion> _filteredLegalOpinions = [];
  bool _hasInternetConnection = true;
  bool _isLoading = true;
  int _currentPage = 1;
  bool _isFetchingMore = false;
  bool _hasMoreData = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // fetchLegalOpinions();
    _loadContentIfConnected();
    _checkInternetConnection();
    Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> result) {
      if (result.contains(ConnectivityResult.none)) {
        setState(() {
          _hasInternetConnection = false;
        });
      } else {
        _loadContentIfConnected();
      }
    });

    //ORIGINAL PAGINATION _scrolLController
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        fetchLegalOpinions(isLoadMore: true);
      }
    });
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 100),
      lowerBound: 0.1,
      upperBound: 1.0,
    );

    _scaleAnimation =
        Tween<double>(begin: 1.0, end: 0.9).animate(_animationController);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    _animationController.forward().then((_) {
      _animationController.reverse();
      _scrollController.animateTo(
        0,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _loadContentIfConnected() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      setState(() {
        _hasInternetConnection = true;
      });
      fetchLegalOpinions();
    }
  }

  Future<void> _checkInternetConnection() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      setState(() {
        _hasInternetConnection = false;
      });
    }
  }

  Future<void> _openWifiSettings() async {
    const url = 'app-settings:';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Unable to open Wi-Fi settings'),
            content: Text(
                'Please open your Wi-Fi settings manually via the device settings.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> fetchLegalOpinions({
    bool isLoadMore = false,
    String? searchQuery,
  }) async {
    if (_isFetchingMore ||
        (!isLoadMore && searchQuery == null && !_hasMoreData)) {
      return;
    }

    if (!isLoadMore && searchQuery == null) {
      setState(() {
        _isLoading = true;
      });
    }

    setState(() {
      _isFetchingMore = true;
    });

    try {
      final Map<String, String> queryParams = {
        'page': _currentPage.toString(),
        'per_page': '50',
      };

      if (searchQuery != null && searchQuery.isNotEmpty) {
        queryParams['search'] = searchQuery;
      }

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

        final newItems =
            data.map((item) => LegalOpinion.fromJson(item)).toList();

        setState(() {
          if (isLoadMore) {
            _legalOpinions.addAll(newItems);
            _filteredLegalOpinions.addAll(newItems);
          } else {
            _legalOpinions = newItems;
            _filteredLegalOpinions = newItems;
          }

          if (searchQuery == null) {
            _hasMoreData =
                _currentPage < (responseData['pagination']?['last_page'] ?? 1);
            if (_hasMoreData) _currentPage++;
          } else {
            _hasMoreData = false;
          }
        });
      } else {
        print('Failed to load legal opinions: ${response.statusCode}');
      }
    } catch (error) {
      print('Error fetching data: $error');
    } finally {
      setState(() {
        _isFetchingMore = false;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(Duration(milliseconds: 500), () {
      if (query.isEmpty) {
        setState(() {
          _currentPage = 1;
          _hasMoreData = true;
          _filteredLegalOpinions = [];
        });
        fetchLegalOpinions();
      } else {
        if (query.length >= 3) {
          setState(() {
            _currentPage = 1;
            _hasMoreData = true;
            _filteredLegalOpinions = [];
            _isLoading = true;
          });
          fetchLegalOpinions(searchQuery: query);
        } else {
          setState(() {
            _filteredLegalOpinions = _legalOpinions.where((opinion) {
              return opinion.title
                      .toLowerCase()
                      .contains(query.toLowerCase()) ||
                  opinion.reference
                      .toLowerCase()
                      .contains(query.toLowerCase()) ||
                  opinion.category
                      .toLowerCase()
                      .contains(query.toLowerCase()) ||
                  opinion.date.toLowerCase().contains(query.toLowerCase()) ||
                  (opinion.extractedTexts ?? '')
                      .toLowerCase()
                      .contains(query.toLowerCase());
            }).toList();
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Legal Opinions',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        iconTheme: IconThemeData(
          color: Colors.white,
        ),
        backgroundColor: Colors.blue[900],
      ),
      body: Column(
        children: [
          // Persistent search bar that won't rebuild
          Container(
            margin: EdgeInsets.fromLTRB(8, 16, 8, 0),
            padding: EdgeInsets.symmetric(horizontal: 16.0),
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
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 16.0),
              ),
              style: TextStyle(fontSize: 16.0),
              onChanged: _onSearchChanged,
            ),
          ),
          SizedBox(height: 10),
          Expanded(
            child: _hasInternetConnection
                ? (_isLoading ? _buildLoadingWidget() : _buildBody())
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'No internet connection',
                          style: TextStyle(fontSize: 20.0),
                        ),
                        SizedBox(height: 10.0),
                        ElevatedButton(
                          onPressed: _openWifiSettings,
                          child: Text('Connect to Internet'),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: _scaleAnimation,
        child: FloatingActionButton(
          onPressed: _scrollToTop,
          child: Icon(Icons.arrow_upward, color: Colors.white),
          backgroundColor: Colors.blue[800],
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Loading Files',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        children: [
          ListView.builder(
            physics: NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: _filteredLegalOpinions.isNotEmpty
                ? _filteredLegalOpinions.length + 1
                : 1,
            itemBuilder: (context, index) {
              if (_filteredLegalOpinions.isEmpty) {
                return Center(child: Text("No results found."));
              }
              if (index == _filteredLegalOpinions.length) {
                return _hasMoreData
                    ? Center(child: CircularProgressIndicator())
                    : SizedBox.shrink();
              }
              return _buildLegalOpinionItem(_filteredLegalOpinions[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLegalOpinionItem(LegalOpinion opinion) {
    return InkWell(
      onTap: () => _navigateToDetailsPage(context, opinion),
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[900]?.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.article, color: Colors.blue[900], size: 28),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      highlightMatches(opinion.title, _searchController.text),
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    if (opinion.reference != 'N/A' &&
                        opinion.reference.isNotEmpty)
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Ref #: ',
                              style: TextStyle(
                                fontSize: 14,
                              ),
                            ),
                            highlightMatches(
                                opinion.reference, _searchController.text),
                          ],
                        ),
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    SizedBox(height: 4),
                    if (opinion.category != 'N/A' &&
                        opinion.category.isNotEmpty)
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Category: ',
                            ),
                            highlightMatches(
                                opinion.reference, _searchController.text),
                          ],
                        ),
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (opinion.extractedTexts != null &&
                        opinion.extractedTexts!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: Colors.grey[800], // Add grey color here
                              fontSize:
                                  14, // Optional: adjust font size if needed
                            ),
                            children: highlightMatches(
                              opinion.extractedTexts!,
                              _searchController.text,
                            ).children, // Preserve your highlight matches
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text.rich(
                        highlightMatches(
                            _formatDate(opinion.date), _searchController.text),
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.blueGrey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

//ORIGINAL _filterLegalOpinions method
  void _filterLegalOpinions(String query) {
    setState(() {
      _filteredLegalOpinions = _legalOpinions.where((opinion) {
        final title = opinion.title.toLowerCase();
        final referenceNo = opinion.reference.toLowerCase();
        final category = opinion.category.toLowerCase();
        final date = opinion.date.toLowerCase();
        final extractedTexts = opinion.extractedTexts?.toLowerCase() ?? '';
        return title.contains(query.toLowerCase()) ||
            referenceNo.contains(query.toLowerCase()) ||
            category.contains(query.toLowerCase()) ||
            date.contains(query.toLowerCase()) ||
            extractedTexts.contains(query.toLowerCase());
      }).toList();
    });
  }

  String _formatDate(String? dateString) {
    if (dateString == null ||
        dateString.isEmpty ||
        dateString == 'N/A' ||
        dateString == 'No Date') {
      return 'No Date';
    }

    try {
      DateFormat inputFormat = DateFormat('MMMM dd, yyyy');
      DateTime parsedDate = inputFormat.parse(dateString);
      return DateFormat('MMMM dd, yyyy').format(parsedDate);
    } catch (e) {
      print('Error parsing date: $e');
      return 'Invalid Date';
    }
  }

  void _navigateToDetailsPage(BuildContext context, LegalOpinion legal) {
    DateFormat inputFormat = DateFormat('MMMM dd, yyyy');

    DateTime? parsedDate;
    try {
      parsedDate = inputFormat.parse(legal.date);
    } catch (e) {
      print('Error parsing date: $e');
    }

    String formattedDate = _formatDate(legal.date);
    print(legal.link);

    // Build content string dynamically, only including non-empty fields
    StringBuffer contentBuffer = StringBuffer();

    if (formattedDate != 'Invalid date') {
      contentBuffer.writeln(formattedDate);
    }

    if (legal.category.isNotEmpty && legal.category != 'N/A') {
      contentBuffer.writeln(legal.category);
    }

    if (legal.reference.isNotEmpty &&
        legal.reference != 'No Reference' &&
        legal.reference != 'N/A') {
      contentBuffer.writeln(legal.reference);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailsScreen(
          title: legal.title,
          content: contentBuffer.isNotEmpty
              ? contentBuffer.toString()
              : 'No additional information available',
          pdfUrl: legal.downloadLink,
          type: getTypeForDownload(legal.category),
        ),
      ),
    );
  }
}

TextSpan highlightMatches(String fullText, String query) {
  if (query.isEmpty || !fullText.toLowerCase().contains(query.toLowerCase())) {
    // No match - show first lines with ellipsis
    return TextSpan(
      text: _truncateToLines(fullText, 3),
    );
  }

  final queryLower = query.toLowerCase();
  final textLower = fullText.toLowerCase();
  final matchStart = textLower.indexOf(queryLower);
  final matchEnd = matchStart + query.length;

  // Find the paragraph containing the match
  final paragraphStart = fullText.lastIndexOf('\n', matchStart) + 1;
  final paragraphEnd = fullText.indexOf('\n', matchEnd);
  final paragraph = paragraphEnd == -1
      ? fullText.substring(paragraphStart)
      : fullText.substring(paragraphStart, paragraphEnd);

  final lines = fullText.split('\n');
  var displayLines = <String>[];
  int matchLineIndex = 0;

  for (int i = 0; i < lines.length; i++) {
    if (lines[i].toLowerCase().contains(queryLower)) {
      matchLineIndex = i;
      break;
    }
  }

  // Take the matching line and up to 2 previous lines
  final startLine = matchLineIndex > 2 ? matchLineIndex - 2 : 0;
  displayLines = lines.sublist(startLine, matchLineIndex + 1);

  // If we have space, show more context after the match
  if (displayLines.length < 3) {
    final remainingLines = 3 - displayLines.length;
    final endLine = matchLineIndex + 1 + remainingLines;
    if (endLine < lines.length) {
      displayLines.addAll(lines.sublist(matchLineIndex + 1, endLine));
    } else {
      displayLines.addAll(lines.sublist(matchLineIndex + 1));
    }
  }

  // Build the text spans with highlighting
  final result = <TextSpan>[];
  for (int i = 0; i < displayLines.length; i++) {
    final line = displayLines[i];
    if (i == matchLineIndex - startLine) {
      // This is the line with the match
      final matchPos = line.toLowerCase().indexOf(queryLower);
      result.add(TextSpan(
        text: line.substring(0, matchPos),
      ));
      result.add(TextSpan(
        text: line.substring(matchPos, matchPos + query.length),
        style: TextStyle(
          fontSize: 13,
          color: Colors.blue,
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
        ),
      ));
      result.add(TextSpan(
        text: '${line.substring(matchPos + query.length)}'
            '${i < displayLines.length - 1 ? '\n' : ''}',
        style: TextStyle(),
      ));
    } else {
      result.add(TextSpan(
        text: '${line}${i < displayLines.length - 1 ? '\n' : ''}',
        style: TextStyle(),
      ));
    }
  }

  if (displayLines.length < lines.length) {
    result.add(TextSpan(text: '...'));
  }

  return TextSpan(children: result);
}

String _truncateToLines(String text, int maxLines) {
  final lines = text.split('\n');
  if (lines.length <= maxLines) return text;
  return '${lines.take(maxLines).join('\n')}...';
}
