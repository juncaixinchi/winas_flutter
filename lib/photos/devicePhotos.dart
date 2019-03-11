import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:draggable_scrollbar/draggable_scrollbar.dart';

import '../redux/redux.dart';

class AssetItem extends StatefulWidget {
  AssetItem({Key key, this.entity}) : super(key: key);
  final AssetEntity entity;
  @override
  _AssetItemState createState() => _AssetItemState();
}

class _AssetItemState extends State<AssetItem> {
  Uint8List thumbData;

  getThumbData() async {
    thumbData = await widget.entity.thumbDataWithSize(200, 200);
    if (this.mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    getThumbData();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: thumbData == null
          ? Container(
              color: Colors.grey[200],
            )
          : Image.memory(thumbData, fit: BoxFit.cover),
    );
  }
}

class DevicePhotos extends StatefulWidget {
  DevicePhotos({Key key, this.album}) : super(key: key);
  final LocalAlbum album;
  @override
  _DevicePhotosState createState() => _DevicePhotosState();
}

class _DevicePhotosState extends State<DevicePhotos> {
  ScrollController myScrollController = ScrollController();

  /// crossAxisCount in Gird
  int lineCount = 4;

  /// mainAxisSpacing and crossAxisSpacing in Grid
  final double spacing = 4.0;

  ///  height of header
  final double headerHeight = 32;

  @override
  Widget build(BuildContext context) {
    final list = widget.album.items;
    return StoreConnector<AppState, AppState>(
      onInit: (store) => {},
      onDispose: (store) => {},
      converter: (store) => store.state,
      builder: (ctx, state) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              widget.album.name,
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.normal,
              ),
            ),
            backgroundColor: Colors.white,
            brightness: Brightness.light,
            elevation: 2.0,
            iconTheme: IconThemeData(color: Colors.black38),
          ),
          body: Container(
            color: Colors.grey[100],
            child: DraggableScrollbar.semicircle(
              controller: myScrollController,
              // labelTextBuilder: (double offset) => getDate(offset, mapHeight),
              labelConstraints: BoxConstraints.expand(width: 88, height: 36),
              child: CustomScrollView(
                key: Key(list.length.toString()),
                controller: myScrollController,
                physics: AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: lineCount,
                      mainAxisSpacing: spacing,
                      crossAxisSpacing: spacing,
                      childAspectRatio: 1.0,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) {
                        final entity = list[index];
                        return AssetItem(entity: entity);
                      },
                      childCount: list.length,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}