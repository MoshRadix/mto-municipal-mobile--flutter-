import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class IssuePhoto extends StatelessWidget {
  const IssuePhoto({
    super.key,
    this.source,
    this.localPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  final String? source;
  final String? localPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius borderRadius;

  Uint8List? _decodeDataUri(String value) {
    if (!value.startsWith('data:')) return null;
    final separator = value.indexOf(',');
    if (separator < 0) return null;

    try {
      return base64Decode(value.substring(separator + 1));
    } on FormatException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = _PhotoPlaceholder(width: width, height: height);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = width != null && width!.isFinite
        ? (width! * pixelRatio).round()
        : null;
    final cacheHeight = height != null && height!.isFinite
        ? (height! * pixelRatio).round()
        : null;
    Widget image;

    if (localPath != null && localPath!.isNotEmpty) {
      image = Image.file(
        File(localPath!),
        width: width,
        height: height,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        fit: fit,
        errorBuilder: (_, _, _) => placeholder,
      );
    } else if (source != null && source!.isNotEmpty) {
      final bytes = _decodeDataUri(source!);
      image = bytes != null
          ? Image.memory(
              bytes,
              width: width,
              height: height,
              cacheWidth: cacheWidth,
              cacheHeight: cacheHeight,
              fit: fit,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => placeholder,
            )
          : Image.network(
              source!,
              width: width,
              height: height,
              cacheWidth: cacheWidth,
              cacheHeight: cacheHeight,
              fit: fit,
              errorBuilder: (_, _, _) => placeholder,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return _PhotoPlaceholder(
                  width: width,
                  height: height,
                  isLoading: true,
                );
              },
            );
    } else {
      image = placeholder;
    }

    return ClipRRect(borderRadius: borderRadius, child: image);
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({this.width, this.height, this.isLoading = false});

  final double? width;
  final double? height;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFEFF4F6),
      alignment: Alignment.center,
      child: isLoading
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(
              Icons.image_not_supported_outlined,
              color: Color(0xFF8CA0A8),
            ),
    );
  }
}
