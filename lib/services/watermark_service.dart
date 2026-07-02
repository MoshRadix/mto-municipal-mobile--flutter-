import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class WatermarkService {
  // Add overlay to an image and return the new file path
  Future<String> addWatermark({
    required String imagePath,
    required String issueTitle,
    required String gpsCoordinates,
    required String readableAddress,
    required bool isDhivehi,
  }) async {
    final File imageFile = File(imagePath);
    if (!await imageFile.exists()) {
      throw Exception('Original image file does not exist.');
    }

    final Uint8List imageBytes = await imageFile.readAsBytes();
    final ByteData logoData = await rootBundle.load(
      'assets/images/adducity_logo.png',
    );

    // Decode image to get width and height
    final ui.Image originalImage = await decodeImageFromList(imageBytes);
    final ui.Image councilLogo = await decodeImageFromList(
      logoData.buffer.asUint8List(),
    );
    final int width = originalImage.width;
    final int height = originalImage.height;

    // Create PictureRecorder and Canvas
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);

    // 1. Draw original image
    final ui.Paint paint = ui.Paint()..filterQuality = ui.FilterQuality.high;
    canvas.drawImage(originalImage, Offset.zero, paint);

    final double shortestSide = math.min(width.toDouble(), height.toDouble());
    // Keep the watermark visually consistent across camera resolutions. Fixed
    // upper bounds made it tiny on modern high-resolution phone photos.
    final double outerPadding = math.max(18.0, shortestSide * 0.03);
    final double cardPadding = math.max(16.0, shortestSide * 0.022);
    final double cornerRadius = math.max(16.0, shortestSide * 0.02);
    final double bodyFontSize = math.max(17.0, shortestSide * 0.022);
    final double roadFontSize = bodyFontSize * 1.42;
    final double councilFontSize = bodyFontSize * 0.92;
    final double supportingFontSize = bodyFontSize * 0.9;
    final double logoBadgeHeight = bodyFontSize * 2.25;
    final double logoBadgeWidth = logoBadgeHeight;
    final double logoBadgePadding = logoBadgeHeight * 0.1;
    final double brandingGap = bodyFontSize * 0.55;

    // Determine Maldives Time (UTC+5)
    // The system metadata says the current user local time is: 2026-07-01T23:07:07+05:00.
    // So we can format the Maldives time. Since the device time is already Maldives local time (the user is in Maldives or emulator is set),
    // we can just format the current date/time, or convert UTC to UTC+5 if needed.
    // We will format the current DateTime using the Maldives format: weekday, date, month, year, time.
    final DateTime maldivesTime = DateTime.now().toUtc().add(
      const Duration(hours: 5),
    );

    // Format Maldives Date & Time
    final String weekdayStr = _getWeekdayString(
      maldivesTime.weekday,
      isDhivehi,
    );
    final String dateStr = DateFormat('d MMMM yyyy').format(maldivesTime);
    final String timeStr = DateFormat('hh:mm a').format(maldivesTime);

    final String dateTimeLabel = isDhivehi
        ? '$weekdayStr، $dateStr، $timeStr'
        : '$weekdayStr, $dateStr, $timeStr';

    final String councilText = isDhivehi
        ? 'އައްޑޫ ސިޓީ ކައުންސިލް'
        : 'Addu City Council';
    final String safeTitle = issueTitle.trim().isEmpty
        ? (isDhivehi ? 'ސުރުޚީއެއް ނެތް' : 'Untitled issue')
        : issueTitle.trim();
    final String safeAddress = readableAddress.trim().isEmpty
        ? (isDhivehi ? 'ލޮކޭޝަން ނޭނގޭ' : 'Location unavailable')
        : readableAddress.trim();
    final String locationLabel = '$safeAddress  •  $gpsCoordinates';

    // Set up TextDirection based on language
    final ui.TextDirection textDirection = isDhivehi
        ? ui.TextDirection.rtl
        : ui.TextDirection.ltr;

    final String? fontFamily = isDhivehi ? 'Faruma' : null;
    final TextAlign textAlign = isDhivehi ? TextAlign.right : TextAlign.left;

    final TextPainter brandingPainter = TextPainter(
      text: TextSpan(
        text: councilText,
        style: TextStyle(
          color: const ui.Color(0xFF8DE3DD),
          fontSize: councilFontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: isDhivehi ? 0 : 1.4,
          fontFamily: fontFamily,
        ),
      ),
      textDirection: textDirection,
      textAlign: textAlign,
      textWidthBasis: TextWidthBasis.longestLine,
      maxLines: 1,
      ellipsis: '…',
    );

    final TextPainter roadPainter = TextPainter(
      text: TextSpan(
        text: safeTitle,
        style: TextStyle(
          color: Colors.white,
          fontSize: roadFontSize,
          height: 1.08,
          fontWeight: FontWeight.w700,
          fontFamily: fontFamily,
        ),
      ),
      textDirection: textDirection,
      textAlign: textAlign,
      textWidthBasis: TextWidthBasis.longestLine,
    );

    final TextPainter locationPainter = TextPainter(
      text: TextSpan(
        text: locationLabel,
        style: TextStyle(
          color: const ui.Color(0xFFE2F0F1),
          fontSize: supportingFontSize,
          height: 1.25,
          fontWeight: FontWeight.w500,
          fontFamily: fontFamily,
        ),
      ),
      textDirection: textDirection,
      textAlign: textAlign,
      textWidthBasis: TextWidthBasis.longestLine,
    );

    final TextPainter timePainter = TextPainter(
      text: TextSpan(
        text: dateTimeLabel,
        style: TextStyle(
          color: const ui.Color(0xFFF1F7F7),
          fontSize: supportingFontSize,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
        ),
      ),
      textDirection: textDirection,
      textAlign: textAlign,
      textWidthBasis: TextWidthBasis.longestLine,
      maxLines: 1,
      ellipsis: '…',
    );

    final double iconSize = bodyFontSize * 1.05;
    final double textInset = iconSize + bodyFontSize * 0.62;
    final double maxCardWidth = width - outerPadding * 2;
    final double maxContentWidth = maxCardWidth - cardPadding * 2;
    final double locationTextWidth = math.max(0, maxContentWidth - textInset);

    timePainter.layout(maxWidth: maxContentWidth * 0.42);
    final double pillHorizontalPadding = supportingFontSize * 0.7;
    final double pillVerticalPadding = supportingFontSize * 0.38;
    final double pillWidth = timePainter.width + pillHorizontalPadding * 2;
    final double pillHeight = timePainter.height + pillVerticalPadding * 2;
    brandingPainter.layout(
      maxWidth: math.max(
        0,
        maxContentWidth - logoBadgeWidth - brandingGap * 2 - pillWidth,
      ),
    );
    roadPainter.layout(maxWidth: maxContentWidth);
    locationPainter.layout(maxWidth: locationTextWidth);

    // Size the card to its longest rendered row instead of spanning the photo.
    final double brandingRowWidth =
        logoBadgeWidth +
        brandingGap +
        brandingPainter.width +
        brandingGap +
        pillWidth;
    final double locationRowWidth = textInset + locationPainter.width;
    final double contentWidth = math.min(
      maxContentWidth,
      math.max(brandingRowWidth, math.max(roadPainter.width, locationRowWidth)),
    );
    final double cardWidth = contentWidth + cardPadding * 2;
    final double cardLeft = isDhivehi
        ? width - outerPadding - cardWidth
        : outerPadding;
    final double cardRight = cardLeft + cardWidth;

    final double gapSmall = bodyFontSize * 0.3;
    final double gapMedium = bodyFontSize * 0.5;
    final double brandingRowHeight = math.max(
      math.max(brandingPainter.height, logoBadgeHeight),
      pillHeight,
    );
    final double cardHeight =
        cardPadding * 2 +
        brandingRowHeight +
        gapSmall +
        gapSmall +
        roadPainter.height +
        gapMedium +
        math.max(locationPainter.height, iconSize);
    final double cardTop = height - outerPadding - cardHeight;

    final ui.RRect card = ui.RRect.fromRectAndRadius(
      ui.Rect.fromLTWH(cardLeft, cardTop, cardWidth, cardHeight),
      ui.Radius.circular(cornerRadius),
    );
    canvas.drawRRect(
      card,
      ui.Paint()
        ..shader = ui.Gradient.linear(
          Offset(cardLeft, cardTop),
          Offset(cardRight, cardTop + cardHeight),
          const [ui.Color(0xED10272C), ui.Color(0xE8183439)],
        )
        ..style = ui.PaintingStyle.fill,
    );
    canvas.drawRRect(
      card,
      ui.Paint()
        ..color = const ui.Color(0x3DFFFFFF)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, shortestSide * 0.0018),
    );

    final double accentWidth = math.max(4.0, shortestSide * 0.006);
    final ui.RRect accent = ui.RRect.fromRectAndRadius(
      ui.Rect.fromLTWH(
        isDhivehi ? cardRight - accentWidth : cardLeft,
        cardTop + cornerRadius,
        accentWidth,
        cardHeight - cornerRadius * 2,
      ),
      ui.Radius.circular(accentWidth),
    );
    canvas.drawRRect(accent, ui.Paint()..color = const ui.Color(0xFF43C6BE));

    final double contentLeft = cardLeft + cardPadding;
    final double contentRight = cardRight - cardPadding;
    double currentY = cardTop + cardPadding;

    Offset alignedOffset(TextPainter painter, double y) =>
        Offset(isDhivehi ? contentRight - painter.width : contentLeft, y);

    final double logoLeft = contentLeft;
    final ui.Rect logoBadge = ui.Rect.fromLTWH(
      logoLeft,
      currentY,
      logoBadgeWidth,
      logoBadgeHeight,
    );
    canvas.drawOval(logoBadge, ui.Paint()..color = const ui.Color(0xF2FFFFFF));
    canvas.drawOval(
      logoBadge,
      ui.Paint()
        ..color = const ui.Color(0x3343C6BE)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, shortestSide * 0.0015),
    );
    final double logoAspect = councilLogo.width / councilLogo.height;
    final double availableLogoWidth = logoBadgeWidth - logoBadgePadding * 2;
    final double availableLogoHeight = logoBadgeHeight - logoBadgePadding * 2;
    final double renderedLogoWidth = math.min(
      availableLogoWidth,
      availableLogoHeight * logoAspect,
    );
    final double renderedLogoHeight = renderedLogoWidth / logoAspect;
    canvas.drawImageRect(
      councilLogo,
      ui.Rect.fromLTWH(
        0,
        0,
        councilLogo.width.toDouble(),
        councilLogo.height.toDouble(),
      ),
      ui.Rect.fromLTWH(
        logoLeft + (logoBadgeWidth - renderedLogoWidth) / 2,
        currentY + (logoBadgeHeight - renderedLogoHeight) / 2,
        renderedLogoWidth,
        renderedLogoHeight,
      ),
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );

    final double brandingTextX = logoLeft + logoBadgeWidth + brandingGap;
    brandingPainter.paint(
      canvas,
      Offset(
        brandingTextX,
        currentY + (brandingRowHeight - brandingPainter.height) / 2,
      ),
    );

    final double pillLeft = contentRight - pillWidth;
    final double pillTop = currentY + (brandingRowHeight - pillHeight) / 2;
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(pillLeft, pillTop, pillWidth, pillHeight),
        ui.Radius.circular(pillHeight / 2),
      ),
      ui.Paint()..color = const ui.Color(0x24FFFFFF),
    );
    timePainter.paint(
      canvas,
      Offset(pillLeft + pillHorizontalPadding, pillTop + pillVerticalPadding),
    );
    currentY += brandingRowHeight + gapSmall;

    canvas.drawLine(
      Offset(contentLeft, currentY),
      Offset(contentRight, currentY),
      ui.Paint()
        ..color = const ui.Color(0x2EFFFFFF)
        ..strokeWidth = math.max(1.0, shortestSide * 0.0012),
    );
    currentY += gapSmall;

    roadPainter.paint(canvas, alignedOffset(roadPainter, currentY));
    currentY += roadPainter.height + gapMedium;

    final double iconCenterX = isDhivehi
        ? contentRight - iconSize / 2
        : contentLeft + iconSize / 2;
    final double iconCenterY = currentY + iconSize / 2;
    canvas.drawCircle(
      Offset(iconCenterX, iconCenterY),
      iconSize / 2,
      ui.Paint()..color = const ui.Color(0x3343C6BE),
    );
    final ui.Path pinPath = ui.Path()
      ..moveTo(iconCenterX, iconCenterY + iconSize * 0.3)
      ..cubicTo(
        iconCenterX - iconSize * 0.08,
        iconCenterY + iconSize * 0.18,
        iconCenterX - iconSize * 0.24,
        iconCenterY,
        iconCenterX - iconSize * 0.24,
        iconCenterY - iconSize * 0.12,
      )
      ..cubicTo(
        iconCenterX - iconSize * 0.24,
        iconCenterY - iconSize * 0.45,
        iconCenterX + iconSize * 0.24,
        iconCenterY - iconSize * 0.45,
        iconCenterX + iconSize * 0.24,
        iconCenterY - iconSize * 0.12,
      )
      ..cubicTo(
        iconCenterX + iconSize * 0.24,
        iconCenterY,
        iconCenterX + iconSize * 0.08,
        iconCenterY + iconSize * 0.18,
        iconCenterX,
        iconCenterY + iconSize * 0.3,
      )
      ..close();
    canvas.drawPath(pinPath, ui.Paint()..color = const ui.Color(0xFF8DE3DD));
    canvas.drawCircle(
      Offset(iconCenterX, iconCenterY - iconSize * 0.13),
      iconSize * 0.075,
      ui.Paint()..color = const ui.Color(0xFF173238),
    );

    locationPainter.paint(
      canvas,
      Offset(
        isDhivehi
            ? contentRight - textInset - locationPainter.width
            : contentLeft + textInset,
        currentY,
      ),
    );

    // 7. Render Canvas back to Image
    final ui.Picture picture = recorder.endRecording();
    final ui.Image watermarkedImage = await picture.toImage(width, height);

    // 8. Convert to PNG bytes
    final ByteData? byteData = await watermarkedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (byteData == null) {
      throw Exception('Failed to encode image to PNG.');
    }
    final Uint8List pngBytes = byteData.buffer.asUint8List();

    // 9. Clean up resources
    originalImage.dispose();
    councilLogo.dispose();
    watermarkedImage.dispose();

    // 10. Write watermarked bytes to a new file in temporary directory
    final Directory tempDir = await getTemporaryDirectory();
    final String tempPath =
        '${tempDir.path}/watermarked_${DateTime.now().millisecondsSinceEpoch}.png';
    final File watermarkedFile = File(tempPath);
    await watermarkedFile.writeAsBytes(pngBytes);

    return tempPath;
  }

  String _getWeekdayString(int day, bool isDhivehi) {
    if (isDhivehi) {
      switch (day) {
        case 1:
          return 'ހޯމަ';
        case 2:
          return 'އަންގާރަ';
        case 3:
          return 'ބުދަ';
        case 4:
          return 'ބުރާސްފަތި';
        case 5:
          return 'ހުކުރު';
        case 6:
          return 'ހޮނިހިރު';
        case 7:
          return 'އާދީއްތަ';
        default:
          return '';
      }
    } else {
      switch (day) {
        case 1:
          return 'Monday';
        case 2:
          return 'Tuesday';
        case 3:
          return 'Wednesday';
        case 4:
          return 'Thursday';
        case 5:
          return 'Friday';
        case 6:
          return 'Saturday';
        case 7:
          return 'Sunday';
        default:
          return '';
      }
    }
  }
}
