import 'dart:async';
import 'dart:convert';
import 'package:DILGDOCS/Services/globals.dart';
import '../models/presidential_directives.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'details_screen.dart';
import 'package:http/http.dart' as http;

class PresidentialDirectives extends StatefulWidget {
  @override
  State<PresidentialDirectives> createState() => _PresidentialDirectivesState();
}

class _PresidentialDirectivesState extends State<PresidentialDirectives>
    with SingleTickerProviderStateMixin {
  TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  List<PresidentialDirective> _presidentialDirectives = [];
  List<PresidentialDirective> _filteredPresidentialDirectives = [];
  bool _hasInternetConnection = true;
  bool _isLoading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
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
    _searchController.dispose();
    _debounce?.cancel();
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
      fetchPresidentialDirectives();
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
      // Provide a generic message for both Android and iOS users
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

  Future<void> fetchPresidentialDirectives() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('$baseURL/presidential_directives'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final List<dynamic> data = responseData['presidentials'];

        setState(() {
          _presidentialDirectives =
              data.map((item) => PresidentialDirective.fromJson(item)).toList();
          _filteredPresidentialDirectives = _presidentialDirectives;
          _isLoading = false;
        });
      } else {
        print('Failed to load presidential directives: ${response.statusCode}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (error) {
      print('Error fetching data: $error');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Future<void> fetchPresidentialCirculars() async {
  //   final response = await http.get(
  //     Uri.parse('$baseURL/presidential_directives'),
  //     headers: {
  //       'Accept': 'application/json',
  //     },
  //   );
  //   if (response.statusCode == 200) {
  //     final List<dynamic>? data = json.decode(response.body)['presidentials'];

  //     if (data != null) {
  //       setState(() {
  //         _presidentialDirectives =
  //             data.map((item) => PresidentialDirective.fromJson(item)).toList();
  //         _filteredPresidentialDirectives = _presidentialDirectives;
  //         _isLoading = false;
  //       });
  //     }
  //   } else {
  //     // Handle error
  //     print('Failed to load latest issuances');
  //     print('Response status code: ${response.statusCode}');
  //     print('Response body: ${response.body}');
  //   }
  // }

  void _filterPresidentialDirectives(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(Duration(milliseconds: 500), () {
      setState(() {
        if (query.isEmpty) {
          _filteredPresidentialDirectives = _presidentialDirectives;
        } else {
          _filteredPresidentialDirectives =
              _presidentialDirectives.where((act) {
            final title = act.title.toLowerCase();
            final reference = act.reference.toLowerCase();
            final date = act.date.toLowerCase();
            final queryLower = query.toLowerCase();

            return title.contains(queryLower) ||
                reference.contains(queryLower) ||
                date.contains(queryLower);
          }).toList();
        }
      });
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
      // Try parsing ISO format first (e.g., "2012-02-13")
      if (dateString.contains('-')) {
        DateTime parsedDate = DateTime.parse(dateString);
        return DateFormat('MMMM dd, yyyy').format(parsedDate);
      }
      // Try parsing the full month name format (e.g., "February 13, 2012")
      else if (dateString.contains(',')) {
        DateFormat inputFormat = DateFormat('MMMM dd, yyyy');
        DateTime parsedDate = inputFormat.parse(dateString);
        return DateFormat('MMMM dd, yyyy').format(parsedDate);
      }
      // If neither format matches, return the original string
      return dateString;
    } catch (e) {
      print('Error parsing date "$dateString": $e');
      return 'Invalid Date';
    }
  }

  void _navigateToDetailsPage(
      BuildContext context, PresidentialDirective directive) {
    String formattedDate = _formatDate(directive.date);
    print('Presidential Directive PDF URL: ${directive.downloadLink}');

    StringBuffer contentBuffer = StringBuffer();

    if (formattedDate != 'Invalid Date' && formattedDate != 'No Date') {
      contentBuffer.writeln(formattedDate);
    }

    if (directive.reference.isNotEmpty &&
        directive.reference != 'No Reference' &&
        directive.reference != 'N/A') {
      contentBuffer.writeln('Ref #: ${directive.reference}');
    }

    final pdfUrl = directive.downloadLink.isNotEmpty
        ? directive.downloadLink
        : directive.link;

    if (!Uri.parse(pdfUrl).isAbsolute ||
        !pdfUrl.toLowerCase().endsWith('.pdf')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid PDF URL: $pdfUrl')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailsScreen(
          title: directive.title,
          content: contentBuffer.isNotEmpty
              ? contentBuffer.toString()
              : 'No additional information available',
          pdfUrl: pdfUrl,
          type: 'Presidential Directive',
        ),
      ),
    );
  }

  // String _formatDate(String? dateString) {
  //   if (dateString == null ||
  //       dateString.isEmpty ||
  //       dateString == 'N/A' ||
  //       dateString == 'No Date') {
  //     return 'No Date';
  //   }

  //   try {
  //     DateFormat inputFormat = DateFormat('MMMM dd, yyyy');
  //     DateTime parsedDate = inputFormat.parse(dateString);
  //     return DateFormat('MMMM dd, yyyy').format(parsedDate);
  //   } catch (e) {
  //     print('Error parsing date: $e');
  //     return 'Invalid Date';
  //   }
  // }

  // void _navigateToDetailsPage(
  //     BuildContext context, PresidentialDirective directive) {
  //   String formattedDate = _formatDate(directive.date);
  //   print('Republic Act PDF URL: ${directive.downloadLink}');

  //   StringBuffer contentBuffer = StringBuffer();

  //   if (formattedDate != 'Invalid date') {
  //     contentBuffer.writeln(formattedDate);
  //   }

  //   if (directive.reference.isNotEmpty &&
  //       directive.reference != 'No Reference' &&
  //       directive.reference != 'N/A') {
  //     contentBuffer.writeln('Ref #: ${directive.reference}');
  //   }

  //   final pdfUrl = directive.downloadLink.isNotEmpty
  //       ? directive.downloadLink
  //       : directive.link;
  //   if (!Uri.parse(pdfUrl).isAbsolute ||
  //       !pdfUrl.toLowerCase().endsWith('.pdf')) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Invalid PDF URL: $pdfUrl')),
  //     );
  //     return;
  //   }

  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => DetailsScreen(
  //         title: directive.title,
  //         content: contentBuffer.isNotEmpty
  //             ? contentBuffer.toString()
  //             : 'No additional information available',
  //         pdfUrl: pdfUrl,
  //         type: 'Presidential Directive',
  //       ),
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Presidential Directives',
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
              onChanged: _filterPresidentialDirectives,
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
          _filteredPresidentialDirectives.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'No presidential directives found',
                      style: TextStyle(fontSize: 18.0),
                    ),
                  ),
                )
              : ListView.builder(
                  physics: NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: _filteredPresidentialDirectives.length,
                  itemBuilder: (context, index) {
                    return _buildPresidentialDirectiveItem(
                        _filteredPresidentialDirectives[index]);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildPresidentialDirectiveItem(PresidentialDirective directive) {
    return InkWell(
      onTap: () => _navigateToDetailsPage(context, directive),
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
                      highlightMatches(directive.title, _searchController.text),
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    if (directive.reference != 'N/A' &&
                        directive.reference.isNotEmpty)
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
                                directive.reference, _searchController.text),
                          ],
                        ),
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text.rich(
                        highlightMatches(_formatDate(directive.date),
                            _searchController.text),
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
}

TextSpan highlightMatches(String text, String query) {
  if (query.isEmpty) {
    return TextSpan(text: text);
  }

  List<TextSpan> textSpans = [];

  RegExp regex = RegExp(query, caseSensitive: false);

  Iterable<Match> matches = regex.allMatches(text);

  int startIndex = 0;

  for (Match match in matches) {
    textSpans.add(TextSpan(text: text.substring(startIndex, match.start)));

    textSpans.add(TextSpan(
      text: text.substring(match.start, match.end),
      style: TextStyle(
        color: Colors.blue,
        fontWeight: FontWeight.bold,
      ),
    ));

    startIndex = match.end;
  }

  textSpans.add(TextSpan(text: text.substring(startIndex)));

  return TextSpan(children: textSpans);
}
