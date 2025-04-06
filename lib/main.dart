import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:logging/logging.dart';

import 'package:simple_frame_app/simple_frame_app.dart';
import 'package:frame_msg/tx/code.dart';
import 'package:frame_msg/tx/image_sprite_block.dart';
import 'package:frame_msg/tx/sprite.dart';


void main() => runApp(const MainApp());

final _log = Logger("MainApp");

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => MainAppState();
}

/// SimpleFrameAppState mixin helps to manage the lifecycle of the Frame connection outside of this file
class MainAppState extends State<MainApp> with SimpleFrameAppState {

  // show the loaded image in the Flutter UI also
  Image? _image;

  MainAppState() {
    Logger.root.level = Level.INFO;
    Logger.root.onRecord.listen((record) {
      debugPrint('${record.level.name}: [${record.loggerName}] ${record.time}: ${record.message}');
    });
  }

  @override
  void initState() {
    super.initState();
    tryScanAndConnectAndStart(andRun: true);
  }

  @override
  Future<void> run() async {
    currentState = ApplicationState.running;
    if (mounted) setState(() {});

    try {
      // Open the file picker
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);

        // Read the file content
        Uint8List imageBytes = await file.readAsBytes();

        // Update the UI based on the original image
        setState(() {
          _image = Image.memory(imageBytes);
        });

        // yield here a moment in order to show the first image first
        await Future.delayed(const Duration(milliseconds: 10));

        // create the sprite, quantize and dither and scale if required
        var sprite = TxSprite.fromImageBytes(imageBytes: imageBytes);

        // Update the UI with the modified image
        setState(() {
          _image = Image.memory(img.encodePng(sprite.toImage()));
        });

        // create the image sprite block header and its sprite lines
        // based on the sprite
        TxImageSpriteBlock isb = TxImageSpriteBlock(
          image: sprite,
          spriteLineHeight: 20,
          progressiveRender: true);

        // and send the block header then the sprite lines to Frame
        await frame!.sendMessage(0x20, isb.pack());

        for (var sprite in isb.spriteLines) {
          await frame!.sendMessage(0x20, sprite.pack());
        }

      }
      else {
        currentState = ApplicationState.ready;
        if (mounted) setState(() {});
      }
    } catch (e) {
      _log.fine('Error executing application logic: $e');
      currentState = ApplicationState.ready;
      if (mounted) setState(() {});
    }
  }

  @override
  Future<void> cancel() async {
    // remove the displayed image
    await frame!.sendMessage(0x10, TxCode(value: 1).pack());
    _image = null;

    currentState = ApplicationState.ready;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Frame Sprite Viewer',
      theme: ThemeData.dark(),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Frame Sprite Viewer'),
          actions: [getBatteryWidget()]
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              if (_image != null) _image!,
              const Spacer(),
            ],
          ),
        ),
        floatingActionButton: getFloatingActionButtonWidget(const Icon(Icons.file_open), const Icon(Icons.close)),
        persistentFooterButtons: getFooterButtonsWidget(),
      )
    );
  }
}
