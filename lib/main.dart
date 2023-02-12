import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';

const String satMapCacheStoreName = "satStore";
const String streetMapCacheStoreName = "streetStore";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // initialize flutter map cacje
  await FlutterMapTileCaching.initialise();
  FMTC.instance; //
  final satStore = FlutterMapTileCaching.instance(satMapCacheStoreName);
  satStore.manage.create(); // Create the store if necessary
  final streetStore = FlutterMapTileCaching.instance(streetMapCacheStoreName);
  streetStore.manage.create(); // Create the store if necessary

  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  MainAppState createState() => MainAppState();
}

class MainAppState extends State<MainApp> {
  final MapController _mapController = MapController();
  final MapOptions _mapOptions = MapOptions(
    zoom: 16,
    maxZoom: 21,
    minZoom: 1,
    center: LatLng(38.576667, -121.493611),
  );

  bool _showStreetMap = false;
  bool _isDownloading = false;
  late DownloadManagement _managerStreet;
  late DownloadManagement _managerSat;

  late FlutterMap _flutterMap;
  late double _progressValue;
  late String _dowloadMessage;
  IconData mapIcon = Icons.terrain;

  @override
  void initState() {
    _progressValue = 0.0;
    _dowloadMessage = "";
    super.initState();
  }

  void saveView() async {
    LatLngBounds bounds = _mapController.bounds!;

    int successfulTiles = 0;
    int tiles = 0;
    // define region
    TileLayer streetMapOptions = TileLayer(
      urlTemplate:
          "https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}.jpg",
    );

    TileLayer satMapOptions = TileLayer(
      urlTemplate:
          "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}.jpg",
    );

    // define region
    final region = RectangleRegion(bounds);
    final downloadableStreet = region.toDownloadable(1, 18, streetMapOptions,
        parallelThreads: 20, preventRedownload: true, seaTileRemoval: true);
    final downloadableSat = region.toDownloadable(1, 18, satMapOptions,
        parallelThreads: 20, preventRedownload: true, seaTileRemoval: true);
    // download manager
    _managerStreet =
        FlutterMapTileCaching.instance(streetMapCacheStoreName).download;
    _managerSat = FlutterMapTileCaching.instance(satMapCacheStoreName).download;
    tiles = await _managerStreet.check(downloadableStreet) +
        await _managerSat.check(downloadableSat);
    setState(() {
      _isDownloading = true;
      _progressValue = 0;
      _dowloadMessage = "Dowloading map tiles 0/$tiles";
    });
    final broadcastStream = FMTC
        .instance(satMapCacheStoreName)
        .download
        .startForeground(
            region: downloadableSat, bufferMode: DownloadBufferMode.tiles)
        .asBroadcastStream();

    broadcastStream.listen((event) {
      Future.delayed(const Duration(milliseconds: 50)).then((onValue) {
        setState(() {
          _progressValue = successfulTiles / tiles;
          successfulTiles = event.successfulTiles;

          _dowloadMessage = "Dowloading map tiles  $successfulTiles/$tiles";
          // check if not canceled
          if (!_isDownloading) {
            _managerSat.cancel();
            return;
          }
        });
      });
    }).onDone(() {
      if (!_isDownloading) {
        return;
      }
      setState(() {
        _progressValue = (successfulTiles) / tiles;
        ;
        _dowloadMessage = "Dowloading map tiles $successfulTiles/$tiles";
      });

      final broadcastStream = FMTC
          .instance(streetMapCacheStoreName)
          .download
          .startForeground(
              region: downloadableStreet, bufferMode: DownloadBufferMode.tiles)
          .asBroadcastStream();
      broadcastStream.listen((event) {
        Future.delayed(const Duration(milliseconds: 100)).then((onValue) {
          setState(() {
            _progressValue = (successfulTiles + event.successfulTiles) / tiles;

            _dowloadMessage =
                "Dowloading map tiles  ${(successfulTiles + event.successfulTiles)}/$tiles";
            if (!_isDownloading) {
              _managerStreet.cancel();
              return;
            }
          });
        });
      }).onDone(() {
        setState(() {
          _isDownloading = false;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    double updatedProgressValue = _progressValue;

    _flutterMap = FlutterMap(
        options: _mapOptions,
        mapController: _mapController,
        children: [
          _showStreetMap
              ? TileLayer(
                  urlTemplate:
                      "https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}.jpg",
                  // Other parameters still necessary
                  tileProvider:
                      FMTC.instance(streetMapCacheStoreName).getTileProvider(),
                )
              : TileLayer(
                  urlTemplate:
                      "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}.jpg",
                  // Other parameters still necessary
                  tileProvider:
                      FMTC.instance(satMapCacheStoreName).getTileProvider(),
                )
        ]);

    Widget saveViewButton() {
      return Column(children: <Widget>[
        RawMaterialButton(
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          onPressed: () {
            saveView();
          },
          shape: const CircleBorder(),
          elevation: 2.0,
          fillColor: Colors.green,
          padding: const EdgeInsets.all(2.0),
          child: const Icon(
            Icons.save,
            color: Colors.white,
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 2.0, bottom: 5.0),
          padding: const EdgeInsets.only(left: 2.0, right: 2.0),
          decoration: ShapeDecoration(
            color: Colors.black,
            shape: BeveledRectangleBorder(
              borderRadius: BorderRadius.circular(2.0),
            ),
          ),
          child: const Text(
            "Save View",
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ),
      ]);
    }

    Widget mapType() {
      return Column(children: <Widget>[
        RawMaterialButton(
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          onPressed: () {
            setState(() {
              _showStreetMap = !_showStreetMap;
              if (!_showStreetMap) {
                mapIcon = Icons.terrain;
              } else {
                mapIcon = Icons.map;
              }
            });
          },
          shape: const CircleBorder(),
          elevation: 2.0,
          fillColor: Colors.green,
          padding: const EdgeInsets.all(2.0),
          child: Icon(
            mapIcon,
            color: Colors.white,
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 2.0, bottom: 5.0),
          padding: const EdgeInsets.only(left: 2.0, right: 2.0),
          decoration: ShapeDecoration(
            color: Colors.black,
            shape: BeveledRectangleBorder(
              borderRadius: BorderRadius.circular(2.0),
            ),
          ),
          child: Text(
            (!_showStreetMap) ? 'Streets' : 'Satellite',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ),
      ]);
    }

    return MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(),
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            title: const Text("Map Cachce Test"),
            centerTitle: true,
            leading: Container(
              child: _isDownloading
                  ? const SizedBox()
                  : IconButton(
                      icon: Icon(Platform.isAndroid
                          ? Icons.arrow_back
                          : Icons.arrow_back_ios),
                      color: Colors.white,
                      tooltip: "Back",
                      onPressed: () {
                        goBack(context);
                      },
                    ),
            ),
          ),
          body: Stack(
            children: <Widget>[
              Container(
                  foregroundDecoration: _isDownloading
                      ? const BoxDecoration(
                          color: Colors.black,
                          backgroundBlendMode: BlendMode.saturation)
                      : const BoxDecoration(),
                  child: AbsorbPointer(
                      absorbing: _isDownloading,
                      child: Stack(children: [
                        _flutterMap,
                        Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Column(children: <Widget>[
                              mapType(),
                              saveViewButton(),
                            ]),
                          ),
                        ),
                      ]))),
              _isDownloading
                  ? Center(
                      child: Container(
                          width: 300.0,
                          padding: const EdgeInsets.all(20.0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10.0),
                            color: Colors.white,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                  padding: const EdgeInsets.only(
                                      top: 5, bottom: 5.0),
                                  child: Text(
                                    _dowloadMessage,
                                    style: const TextStyle(
                                        fontSize: 14.0, color: Colors.black),
                                  )),
                              LinearProgressIndicator(
                                backgroundColor: const Color(0xff3498db),
                                color: Colors.green,
                                minHeight: 15,
                                value: updatedProgressValue,
                              ),
                              SimpleDialogOption(
                                padding: const EdgeInsets.only(top: 10.0),
                                onPressed: () {
                                  setState(() {
                                    _isDownloading = false;
                                    _managerSat.cancel();
                                    _managerStreet.cancel();
                                  });
                                },
                                child: const Text(
                                  'Cancel',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16.0,
                                  ),
                                ),
                              ),
                            ],
                          )))
                  : const SizedBox(),
            ],
          ),
        ),
      ),
    );
  }

  void goBack(BuildContext context) {}
}
