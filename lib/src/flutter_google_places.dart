library flutter_google_places.src;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_api_headers/google_api_headers.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:http/http.dart';
import 'package:rxdart/rxdart.dart';

class PlacesAutocompleteWidget extends StatefulWidget {
  final String apiKey;
  final String? startText;
  final String hint;
  final BorderRadius? overlayBorderRadius;
  final Location? location;
  final num? offset;
  final num? radius;
  final String? language;
  final String? sessionToken;
  final List<String>? types;
  final List<Component>? components;
  final bool? strictbounds;
  final String? region;
  final Mode mode;
  final Widget? logo;
  final ValueChanged<PlacesAutocompleteResponse>? onError;
  final int debounce;
  final InputDecoration? decoration;
  final TextStyle? textStyle;
  final ThemeData? themeData;

  /// optional - sets 'proxy' value in google_maps_webservice
  ///
  /// In case of using a proxy the baseUrl can be set.
  /// The apiKey is not required in case the proxy sets it.
  /// (Not storing the apiKey in the app is good practice)
  final String? proxyBaseUrl;

  /// optional - set 'client' value in google_maps_webservice
  ///
  /// In case of using a proxy url that requires authentication
  /// or custom configuration
  final BaseClient? httpClient;

  /// If true the [body] and the scaffold's floating widgets should size
  /// themselves to avoid the onscreen keyboard whose height is defined by the
  /// ambient [MediaQuery]'s [MediaQueryData.viewInsets] `bottom` property.
  ///
  /// For example, if there is an onscreen keyboard displayed above the
  /// scaffold, the body can be resized to avoid overlapping the keyboard, which
  /// prevents widgets inside the body from being obscured by the keyboard.
  ///
  /// Defaults to true.
  final bool? resizeToAvoidBottomInset;

  const PlacesAutocompleteWidget({
    required this.apiKey,
    this.mode = Mode.fullscreen,
    this.hint = "Search",
    this.overlayBorderRadius,
    this.offset,
    this.location,
    this.radius,
    this.language,
    this.sessionToken,
    this.types,
    this.components,
    this.strictbounds,
    this.region,
    this.logo,
    this.onError,
    Key? key,
    this.proxyBaseUrl,
    this.httpClient,
    this.startText,
    this.debounce = 300,
    this.decoration,
    this.textStyle,
    this.themeData,
    this.resizeToAvoidBottomInset
  }) : super(key: key);

  @override
  State<PlacesAutocompleteWidget> createState() =>
      _PlacesAutocompleteOverlayState();

  static PlacesAutocompleteState? of(BuildContext context) =>
      context.findAncestorStateOfType<PlacesAutocompleteState>();
}

class _PlacesAutocompleteOverlayState extends PlacesAutocompleteState {
  @override
  Widget build(BuildContext context) {
    final theme = widget.themeData ?? Theme.of(context);
    if (widget.mode == Mode.fullscreen) {
      return Theme(
        data: theme,
        child: Scaffold(
          resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
            appBar: AppBar(
              title: AppBarPlacesAutoCompleteTextField(
                textDecoration: widget.decoration,
                textStyle: widget.textStyle,
              ),
            ),
            body: PlacesAutocompleteResult(
              onTap: Navigator.of(context).pop,
              logo: widget.logo,
            )),
      );
    } else {
      final headerTopLeftBorderRadius = widget.overlayBorderRadius != null
          ? widget.overlayBorderRadius!.topLeft
          : const Radius.circular(2);

      final headerTopRightBorderRadius = widget.overlayBorderRadius != null
          ? widget.overlayBorderRadius!.topRight
          : const Radius.circular(2);

      final header = Column(children: <Widget>[
        Material(
            color: theme.dialogBackgroundColor,
            borderRadius: BorderRadius.only(
                topLeft: headerTopLeftBorderRadius,
                topRight: headerTopRightBorderRadius),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                IconButton(
                  color: theme.brightness == Brightness.light
                      ? Colors.black45
                      : null,
                  icon: _iconBack,
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                Expanded(
                    child: Padding(
                  child: _textField(context),
                  padding: const EdgeInsets.only(right: 8.0),
                )),
              ],
            )),
        const Divider()
      ]);

      Widget body;

      final bodyBottomLeftBorderRadius = widget.overlayBorderRadius != null
          ? widget.overlayBorderRadius!.bottomLeft
          : const Radius.circular(2);

      final bodyBottomRightBorderRadius = widget.overlayBorderRadius != null
          ? widget.overlayBorderRadius!.bottomRight
          : const Radius.circular(2);

      if (searching) {
        body = Stack(
          children: <Widget>[_Loader()],
          alignment: FractionalOffset.bottomCenter,
        );
      } else if (queryTextController!.text.isEmpty ||
          response == null ||
          response!.predictions.isEmpty) {
        body = Material(
          color: theme.dialogBackgroundColor,
          child: widget.logo ?? const PoweredByGoogleImage(),
          borderRadius: BorderRadius.only(
            bottomLeft: bodyBottomLeftBorderRadius,
            bottomRight: bodyBottomRightBorderRadius,
          ),
        );
      } else {
        body = SingleChildScrollView(
          child: Material(
            borderRadius: BorderRadius.only(
              bottomLeft: bodyBottomLeftBorderRadius,
              bottomRight: bodyBottomRightBorderRadius,
            ),
            color: theme.dialogBackgroundColor,
            child: ListBody(
              children: response!.predictions
                  .map(
                    (p) => PredictionTile(
                      prediction: p,
                      onTap: Navigator.of(context).pop,
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      }

      final container = Container(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 30.0),
          child: Stack(children: <Widget>[
            header,
            Padding(padding: const EdgeInsets.only(top: 48.0), child: body),
          ]));

      if (Theme.of(context).platform == TargetPlatform.iOS) {
        return Padding(
            padding: const EdgeInsets.only(top: 8.0), child: container);
      }
      return container;
    }
  }

  Icon get _iconBack => Theme.of(context).platform == TargetPlatform.iOS
      ? const Icon(Icons.arrow_back_ios)
      : const Icon(Icons.arrow_back);

  Widget _textField(BuildContext context) => TextField(
        controller: queryTextController,
        autofocus: true,
        style: TextStyle(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.black87
                : null,
            fontSize: 16.0),
        decoration: widget.decoration ??
            InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.black45
                    : null,
                fontSize: 16.0,
              ),
              border: InputBorder.none,
            ),
      );
}

class _Loader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        constraints: const BoxConstraints(maxHeight: 2.0),
        child: const LinearProgressIndicator());
  }
}

class PlacesAutocompleteResult extends StatefulWidget {
  final ValueChanged<Prediction>? onTap;
  final Widget? logo;

  const PlacesAutocompleteResult({Key? key, this.onTap, this.logo})
      : super(key: key);

  @override
  _PlacesAutocompleteResult createState() => _PlacesAutocompleteResult();
}

class _PlacesAutocompleteResult extends State<PlacesAutocompleteResult> {
  @override
  Widget build(BuildContext context) {
    final state = PlacesAutocompleteWidget.of(context)!;

    if (state.queryTextController!.text.isEmpty ||
        state.response == null ||
        state.response!.predictions.isEmpty) {
      final children = <Widget>[];
      if (state.searching) {
        children.add(_Loader());
      }
      children.add(widget.logo ?? const PoweredByGoogleImage());
      return ListView(children: children);
    }
    return PredictionsListView(
      predictions: state.response!.predictions,
      onTap: widget.onTap,
    );
  }
}

class AppBarPlacesAutoCompleteTextField extends StatefulWidget {
  final InputDecoration? textDecoration;
  final TextStyle? textStyle;

  const AppBarPlacesAutoCompleteTextField(
      {Key? key, this.textDecoration, this.textStyle})
      : super(key: key);

  @override
  State<AppBarPlacesAutoCompleteTextField> createState() =>
      _AppBarPlacesAutoCompleteTextFieldState();
}

class _AppBarPlacesAutoCompleteTextFieldState extends State<AppBarPlacesAutoCompleteTextField> {
  @override
  Widget build(BuildContext context) {
    final state = PlacesAutocompleteWidget.of(context)!;

    return Container(
        alignment: Alignment.topLeft,
        margin: const EdgeInsets.only(top: 4.0),
        child: TextField(
          controller: state.queryTextController,
          autofocus: true,
          style: widget.textStyle ?? _defaultStyle(),
          decoration:
              widget.textDecoration ?? _defaultDecoration(state.widget.hint),
        ));
  }

  InputDecoration _defaultDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Theme.of(context).brightness == Brightness.light
          ? Colors.white30
          : Colors.black38,
      hintStyle: TextStyle(
        color: Theme.of(context).brightness == Brightness.light
            ? Colors.black38
            : Colors.white30,
        fontSize: 16.0,
      ),
      border: InputBorder.none,
    );
  }

  TextStyle _defaultStyle() {
    return TextStyle(
      color: Theme.of(context).brightness == Brightness.light
          ? Colors.black.withOpacity(0.9)
          : Colors.white.withOpacity(0.9),
      fontSize: 16.0,
    );
  }
}

class PoweredByGoogleImage extends StatelessWidget {
  final _poweredByGoogleWhite =
      "packages/flutter_google_places/assets/google_white.png";
  final _poweredByGoogleBlack =
      "packages/flutter_google_places/assets/google_black.png";

  const PoweredByGoogleImage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
      Padding(
          padding: const EdgeInsets.all(16.0),
          child: Image.asset(
            Theme.of(context).brightness == Brightness.light
                ? _poweredByGoogleWhite
                : _poweredByGoogleBlack,
            scale: 2.5,
          ))
    ]);
  }
}

class PredictionsListView extends StatelessWidget {
  final List<Prediction> predictions;
  final ValueChanged<Prediction>? onTap;

  const PredictionsListView({Key? key, required this.predictions, this.onTap})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: predictions
          .map((Prediction p) => PredictionTile(prediction: p, onTap: onTap))
          .toList(),
    );
  }
}

class PredictionTile extends StatelessWidget {
  final Prediction prediction;
  final ValueChanged<Prediction>? onTap;

  const PredictionTile({Key? key, required this.prediction, this.onTap})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.location_on),
      title: Text(
        prediction.description!,
        style: Theme.of(context).textTheme.bodyText2,
      ),
      onTap: () {
        if (onTap != null) {
          onTap!(prediction);
        }
      },
    );
  }
}

enum Mode { overlay, fullscreen }

abstract class PlacesAutocompleteState extends State<PlacesAutocompleteWidget> {
  TextEditingController? queryTextController;
  PlacesAutocompleteResponse? response;
  GoogleMapsPlaces? places;
  late bool searching;
  Timer? debounce;

  final _queryBehavior = BehaviorSubject<String>.seeded('');

  @override
  void initState() {
    super.initState();

    queryTextController = TextEditingController(text: widget.startText);
    queryTextController!.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.startText?.length ?? 0,
    );

    _initPlaces();
    searching = false;

    queryTextController!.addListener(_onQueryChange);

    _queryBehavior.stream.listen(doSearch);
  }

  Future<void> _initPlaces() async {
    places = GoogleMapsPlaces(
      apiKey: widget.apiKey,
      baseUrl: widget.proxyBaseUrl,
      httpClient: widget.httpClient,
      apiHeaders: await const GoogleApiHeaders().getHeaders(),
    );
  }

  Future<void> doSearch(String value) async {
    if (mounted && value.isNotEmpty && places != null) {
      setState(() {
        searching = true;
      });

      final res = await places!.autocomplete(
        value,
        offset: widget.offset,
        location: widget.location,
        radius: widget.radius,
        language: widget.language,
        sessionToken: widget.sessionToken,
        types: widget.types ?? [],
        components: widget.components ?? [],
        strictbounds: widget.strictbounds ?? false,
        region: widget.region,
      );

      if (res.errorMessage?.isNotEmpty == true ||
          res.status == "REQUEST_DENIED") {
        onResponseError(res);
      } else {
        onResponse(res);
      }
    } else {
      onResponse(null);
    }
  }

  void _onQueryChange() {
    if (debounce?.isActive ?? false) debounce!.cancel();
    debounce = Timer(Duration(milliseconds: widget.debounce), () {
      if (!_queryBehavior.isClosed) {
        _queryBehavior.add(queryTextController!.text);
      }
    });
  }

  @override
  void dispose() {
    super.dispose();

    places?.dispose();
    debounce?.cancel();
    _queryBehavior.close();
    queryTextController!.removeListener(_onQueryChange);
  }

  @mustCallSuper
  void onResponseError(PlacesAutocompleteResponse res) {
    if (!mounted) return;

    if (widget.onError != null) {
      widget.onError!(res);
    }
    setState(() {
      response = null;
      searching = false;
    });
  }

  @mustCallSuper
  void onResponse(PlacesAutocompleteResponse? res) {
    if (!mounted) return;

    setState(() {
      response = res;
      searching = false;
    });
  }
}

class PlacesAutocomplete {
  static Future<Prediction?> show({
    required BuildContext context,
    required String apiKey,
    Mode mode = Mode.fullscreen,
    String hint = "Search",
    BorderRadius? overlayBorderRadius,
    num? offset,
    Location? location,
    num? radius,
    String? language,
    String? sessionToken,
    List<String>? types,
    List<Component>? components,
    bool? strictbounds,
    String? region,
    Widget? logo,
    ValueChanged<PlacesAutocompleteResponse>? onError,
    String? proxyBaseUrl,
    Client? httpClient,
    InputDecoration? decoration,
    String startText = "",
    TextStyle? textStyle,
    ThemeData? themeData,
    bool? resizeToAvoidBottomInset
  }) {
    builder(BuildContext ctx) => PlacesAutocompleteWidget(
          apiKey: apiKey,
          mode: mode,
          overlayBorderRadius: overlayBorderRadius,
          language: language,
          sessionToken: sessionToken,
          components: components,
          types: types,
          location: location,
          radius: radius,
          strictbounds: strictbounds,
          region: region,
          offset: offset,
          hint: hint,
          logo: logo,
          onError: onError,
          proxyBaseUrl: proxyBaseUrl,
          httpClient: httpClient as BaseClient?,
          startText: startText,
          decoration: decoration,
          textStyle: textStyle,
          themeData: themeData,
          resizeToAvoidBottomInset: resizeToAvoidBottomInset
        );

    if (mode == Mode.overlay) {
      return showDialog(context: context, builder: builder);
    }
    return Navigator.push(context, MaterialPageRoute(builder: builder));
  }
}
