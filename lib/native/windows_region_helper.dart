import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:ui';
import 'package:ffi/ffi.dart';
import 'package:flutter/painting.dart';
import '../core/logging/app_logger.dart';

typedef _FindWindowWC = IntPtr Function(Pointer<Utf16> lpClassName, Pointer<Utf16> lpWindowName);
typedef _FindWindowWDart = int Function(Pointer<Utf16> lpClassName, Pointer<Utf16> lpWindowName);

typedef _FindWindowExWC = IntPtr Function(IntPtr hWndParent, IntPtr hWndChildAfter, Pointer<Utf16> lpszClass, Pointer<Utf16> lpszWindow);
typedef _FindWindowExWDart = int Function(int hWndParent, int hWndChildAfter, Pointer<Utf16> lpszClass, Pointer<Utf16> lpszWindow);

typedef _SetWindowRgnC = Int32 Function(IntPtr hWnd, IntPtr hRgn, Int32 bRedraw);
typedef _SetWindowRgnDart = int Function(int hWnd, int hRgn, int bRedraw);

typedef _CreateRectRgnC = IntPtr Function(Int32 x1, Int32 y1, Int32 x2, Int32 y2);
typedef _CreateRectRgnDart = int Function(int x1, int y1, int x2, int y2);

typedef _CombineRgnC = Int32 Function(IntPtr hrgnDest, IntPtr hrgnSrc1, IntPtr hrgnSrc2, Int32 fnCombineMode);
typedef _CombineRgnDart = int Function(int hrgnDest, int hrgnSrc1, int hrgnSrc2, int fnCombineMode);

typedef _DeleteObjectC = Int32 Function(IntPtr hObject);
typedef _DeleteObjectDart = int Function(int hObject);

typedef _GetDpiForWindowC = Uint32 Function(IntPtr hwnd);
typedef _GetDpiForWindowDart = int Function(int hwnd);

typedef _GetWindowLongPtrWC = IntPtr Function(IntPtr hwnd, Int32 nIndex);
typedef _GetWindowLongPtrWDart = int Function(int hwnd, int nIndex);

typedef _SetWindowLongPtrWC = IntPtr Function(IntPtr hwnd, Int32 nIndex, IntPtr dwNewLong);
typedef _SetWindowLongPtrWDart = int Function(int hwnd, int nIndex, int dwNewLong);

typedef _IsWindowC = Int32 Function(IntPtr hwnd);
typedef _IsWindowDart = int Function(int hwnd);

typedef _GetCurrentProcessIdC = Uint32 Function();
typedef _GetCurrentProcessIdDart = int Function();

typedef _GetCurrentProcessC = IntPtr Function();
typedef _GetCurrentProcessDart = int Function();

typedef _SetProcessWorkingSetSizeC = Int32 Function(IntPtr hProcess, IntPtr dwMinimumWorkingSetSize, IntPtr dwMaximumWorkingSetSize);
typedef _SetProcessWorkingSetSizeDart = int Function(int hProcess, int dwMinimumWorkingSetSize, int dwMaximumWorkingSetSize);

typedef _EmptyWorkingSetC = Int32 Function(IntPtr hProcess);
typedef _EmptyWorkingSetDart = int Function(int hProcess);

typedef _EnumWindowsProcC = Int32 Function(IntPtr hwnd, IntPtr lParam);
typedef _EnumWindowsC = Int32 Function(Pointer<NativeFunction<_EnumWindowsProcC>> lpEnumFunc, IntPtr lParam);
typedef _EnumWindowsDart = int Function(Pointer<NativeFunction<_EnumWindowsProcC>> lpEnumFunc, int lParam);

typedef _GetWindowThreadProcessIdC = Uint32 Function(IntPtr hwnd, Pointer<Uint32> lpdwProcessId);
typedef _GetWindowThreadProcessIdDart = int Function(int hwnd, Pointer<Uint32> lpdwProcessId);

typedef _GetClassNameWC = Int32 Function(IntPtr hwnd, Pointer<Utf16> lpClassName, Int32 nMaxCount);
typedef _GetClassNameWDart = int Function(int hwnd, Pointer<Utf16> lpClassName, int nMaxCount);

/// Native Windows window region manager.
///
/// Clips the stage window and Flutter child view to the EXACT interactive
/// boundaries of the dynamic bar. This ensures touches and mouse inputs
/// outside the dynamic bar pass directly to underlying applications without
/// blocking or swallowing input across the screen.
class WindowsRegionHelper {
  static const Logger _log = Logger('RegionHelper');
  static final bool isSupported = Platform.isWindows;

  static DynamicLibrary? _user32;
  static DynamicLibrary? _gdi32;
  static DynamicLibrary? _kernel32;
  static DynamicLibrary? _psapi;

  static _FindWindowWDart? _findWindowW;
  static _FindWindowExWDart? _findWindowExW;
  static _SetWindowRgnDart? _setWindowRgn;
  static _CreateRectRgnDart? _createRectRgn;
  static _CombineRgnDart? _combineRgn;
  static _DeleteObjectDart? _deleteObject;
  static _GetDpiForWindowDart? _getDpiForWindow;
  static _GetWindowLongPtrWDart? _getWindowLongPtrW;
  static _SetWindowLongPtrWDart? _setWindowLongPtrW;
  static _IsWindowDart? _isWindow;
  static _GetCurrentProcessIdDart? _getCurrentProcessId;
  static _GetCurrentProcessDart? _getCurrentProcess;
  static _SetProcessWorkingSetSizeDart? _setProcessWorkingSetSize;
  static _EmptyWorkingSetDart? _emptyWorkingSet;
  static _EnumWindowsDart? _enumWindows;
  static _GetWindowThreadProcessIdDart? _getWindowThreadProcessId;
  static _GetClassNameWDart? _getClassNameW;

  static bool _initialized = false;
  static int _stageHwnd = 0;
  static int _flutterViewHwnd = 0;

  static void _init() {
    if (_initialized || !isSupported) return;
    _initialized = true;

    try {
      _user32 = DynamicLibrary.open('user32.dll');
      _gdi32 = DynamicLibrary.open('gdi32.dll');
      _kernel32 = DynamicLibrary.open('kernel32.dll');

      _findWindowW = _user32!.lookupFunction<_FindWindowWC, _FindWindowWDart>('FindWindowW');
      _findWindowExW = _user32!.lookupFunction<_FindWindowExWC, _FindWindowExWDart>('FindWindowExW');
      _setWindowRgn = _user32!.lookupFunction<_SetWindowRgnC, _SetWindowRgnDart>('SetWindowRgn');
      _createRectRgn = _gdi32!.lookupFunction<_CreateRectRgnC, _CreateRectRgnDart>('CreateRectRgn');
      _combineRgn = _gdi32!.lookupFunction<_CombineRgnC, _CombineRgnDart>('CombineRgn');
      _deleteObject = _gdi32!.lookupFunction<_DeleteObjectC, _DeleteObjectDart>('DeleteObject');
      _isWindow = _user32!.lookupFunction<_IsWindowC, _IsWindowDart>('IsWindow');

      try {
        _getDpiForWindow = _user32!.lookupFunction<_GetDpiForWindowC, _GetDpiForWindowDart>('GetDpiForWindow');
      } catch (_) {}

      try {
        _getWindowLongPtrW = _user32!.lookupFunction<_GetWindowLongPtrWC, _GetWindowLongPtrWDart>('GetWindowLongPtrW');
        _setWindowLongPtrW = _user32!.lookupFunction<_SetWindowLongPtrWC, _SetWindowLongPtrWDart>('SetWindowLongPtrW');
      } catch (_) {
        // Fallback for 32-bit if ever needed
        _getWindowLongPtrW = _user32!.lookupFunction<_GetWindowLongPtrWC, _GetWindowLongPtrWDart>('GetWindowLongW');
        _setWindowLongPtrW = _user32!.lookupFunction<_SetWindowLongPtrWC, _SetWindowLongPtrWDart>('SetWindowLongW');
      }

      _getCurrentProcessId = _kernel32!.lookupFunction<_GetCurrentProcessIdC, _GetCurrentProcessIdDart>('GetCurrentProcessId');
      _getCurrentProcess = _kernel32!.lookupFunction<_GetCurrentProcessC, _GetCurrentProcessDart>('GetCurrentProcess');
      _setProcessWorkingSetSize = _kernel32!.lookupFunction<_SetProcessWorkingSetSizeC, _SetProcessWorkingSetSizeDart>('SetProcessWorkingSetSize');

      try {
        _psapi = DynamicLibrary.open('psapi.dll');
        _emptyWorkingSet = _psapi!.lookupFunction<_EmptyWorkingSetC, _EmptyWorkingSetDart>('EmptyWorkingSet');
      } catch (_) {}

      _enumWindows = _user32!.lookupFunction<_EnumWindowsC, _EnumWindowsDart>('EnumWindows');
      _getWindowThreadProcessId = _user32!.lookupFunction<_GetWindowThreadProcessIdC, _GetWindowThreadProcessIdDart>('GetWindowThreadProcessId');
      _getClassNameW = _user32!.lookupFunction<_GetClassNameWC, _GetClassNameWDart>('GetClassNameW');
    } catch (_) {}
  }

  static int _myPid = 0;
  static Pointer<Uint32>? _pidPtr;
  static Pointer<Uint16>? _nameBuf;

  static int _enumCallback(int hwnd, int lParam) {
    if (_getWindowThreadProcessId != null && _pidPtr != null && _getClassNameW != null && _nameBuf != null) {
      _getWindowThreadProcessId!(hwnd, _pidPtr!);
      if (_pidPtr!.value == _myPid) {
        _getClassNameW!(hwnd, _nameBuf!.cast<Utf16>(), 256);
        final className = _nameBuf!.cast<Utf16>().toDartString();
        if (className == 'DynamicBarIslandStage') {
          _stageHwnd = hwnd;
          return 0;
        }
      }
    }
    return 1;
  }

  static int get stageHwnd {
    _init();
    if (_isWindow != null && _stageHwnd != 0 && _isWindow!(_stageHwnd) != 0) {
      return _stageHwnd;
    }
    _stageHwnd = 0;
    _flutterViewHwnd = 0;

    if (_findWindowW == null) return 0;

    // 1. Direct class lookup verified by PID
    final cls = 'DynamicBarIslandStage'.toNativeUtf16();
    final h = _findWindowW!(cls, nullptr);
    calloc.free(cls);
    if (h != 0) {
      if (_getCurrentProcessId != null && _getWindowThreadProcessId != null) {
        final pidPtr = calloc<Uint32>();
        _getWindowThreadProcessId!(h, pidPtr);
        final winPid = pidPtr.value;
        calloc.free(pidPtr);
        if (winPid == _getCurrentProcessId!()) {
          _stageHwnd = h;
          _findFlutterView();
          return _stageHwnd;
        }
      } else {
        _stageHwnd = h;
        _findFlutterView();
        return _stageHwnd;
      }
    }

    // 2. EnumWindows by PID lookup
    if (_enumWindows != null && _getCurrentProcessId != null && _getWindowThreadProcessId != null && _getClassNameW != null) {
      _myPid = _getCurrentProcessId!();
      _pidPtr = calloc<Uint32>();
      _nameBuf = calloc<Uint16>(256);

      final callbackPtr = Pointer.fromFunction<_EnumWindowsProcC>(_enumCallback, 1);
      _enumWindows!(callbackPtr, 0);

      calloc.free(_pidPtr!);
      calloc.free(_nameBuf!);
      _pidPtr = null;
      _nameBuf = null;
    }

    if (_stageHwnd != 0) {
      _findFlutterView();
    }
    return _stageHwnd;
  }

  static void _findFlutterView() {
    if (_stageHwnd == 0 || _findWindowExW == null) return;
    final cls = 'FLUTTERVIEW'.toNativeUtf16();
    _flutterViewHwnd = _findWindowExW!(_stageHwnd, 0, cls, nullptr);
    calloc.free(cls);
  }

  static double get scale {
    final hwnd = stageHwnd;
    if (hwnd != 0 && _getDpiForWindow != null) {
      final dpi = _getDpiForWindow!(hwnd);
      if (dpi > 0) return dpi / 96.0;
    }
    try {
      return PlatformDispatcher.instance.views.first.devicePixelRatio;
    } catch (_) {
      return 1.0;
    }
  }

  /// Updates the Win32 window clipping region to match [rects].
  ///
  /// Any coordinates outside [rects] are completely transparent to OS hit testing
  /// (mouse, touch, gestures), allowing background apps to be used without interference.
  static void updateRegion(List<Rect> rects) {
    if (!isSupported) return;
    final hwnd = stageHwnd;
    if (hwnd == 0 || _setWindowRgn == null || _createRectRgn == null || _combineRgn == null || _deleteObject == null) {
      _log.warn('updateRegion failed: hwnd=$hwnd');
      return;
    }

    final double s = scale;

    int buildRegion(List<Rect> list) {
      int combined = 0;
      for (final r in list) {
        if (r.isEmpty || r.width <= 0 || r.height <= 0) continue;
        final left = (r.left * s).floor();
        final top = (r.top * s).floor();
        final right = (r.right * s).ceil();
        final bottom = (r.bottom * s).ceil();

        final rgn = _createRectRgn!(left, top, right, bottom);
        if (combined == 0) {
          combined = rgn;
        } else {
          _combineRgn!(combined, combined, rgn, 2 /* RGN_OR */);
          _deleteObject!(rgn);
        }
      }
      return combined;
    }

    final int rgnStage = buildRegion(rects);
    final int rgnChild = buildRegion(rects);

    final int ret1;
    final int ret2;
    if (rgnStage == 0) {
      final empty1 = _createRectRgn!(0, 0, 0, 0);
      ret1 = _setWindowRgn!(hwnd, empty1, 1);
      if (_flutterViewHwnd != 0) {
        final empty2 = _createRectRgn!(0, 0, 0, 0);
        ret2 = _setWindowRgn!(_flutterViewHwnd, empty2, 1);
      } else {
        ret2 = 0;
      }
      _log.info('Clipped stage 0x${hwnd.toRadixString(16)} [ret=$ret1] and view 0x${_flutterViewHwnd.toRadixString(16)} [ret=$ret2] to EMPTY');
    } else {
      ret1 = _setWindowRgn!(hwnd, rgnStage, 1);
      if (_flutterViewHwnd != 0 && rgnChild != 0) {
        ret2 = _setWindowRgn!(_flutterViewHwnd, rgnChild, 1);
      } else if (rgnChild != 0) {
        _deleteObject!(rgnChild);
        ret2 = 0;
      } else {
        ret2 = 0;
      }
      final coords = rects.map((r) => '(${r.left.toInt()},${r.top.toInt()}..${r.right.toInt()},${r.bottom.toInt()})').toList();
      _log.info('Clipped stage 0x${hwnd.toRadixString(16)} [ret=$ret1] and view 0x${_flutterViewHwnd.toRadixString(16)} [ret=$ret2] to $coords (scale=$s)');
    }

    // Clear WS_EX_TRANSPARENT so mouse and touch inside the region are received instantly
    if (_getWindowLongPtrW != null && _setWindowLongPtrW != null) {
      const int gwlExstyle = -20;
      const int wsExTransparent = 0x00000020;
      final exStyle = _getWindowLongPtrW!(hwnd, gwlExstyle);
      if ((exStyle & wsExTransparent) != 0) {
        _setWindowLongPtrW!(hwnd, gwlExstyle, exStyle & ~wsExTransparent);
      }
    }

    // Track whether island is currently expanded based on rect height
    final double maxH = rects.fold(0.0, (m, r) => r.height > m ? r.height : m);
    final bool wasExpanded = isExpanded;
    isExpanded = maxH > 100.0;

    // When the island collapses from expanded, immediately purge memory
    if (wasExpanded && !isExpanded) {
      trimMemory();
    }
  }

  static bool isExpanded = false;
  static Timer? _periodicTrimTimer;
  static DateTime _lastTrim = DateTime.fromMillisecondsSinceEpoch(0);

  /// Aggressively reclaims unneeded memory:
  /// 1. Flushes Flutter image cache.
  /// 2. Invokes Win32 EmptyWorkingSet and SetProcessWorkingSetSize(-1, -1).
  /// Maintains process RAM usage at 20-50 MB.
  static void trimMemory({bool force = false}) {
    if (!isSupported) return;
    final now = DateTime.now();
    if (!force && now.difference(_lastTrim).inMilliseconds < 2000) {
      return;
    }
    _lastTrim = now;

    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {}

    _init();
    if (_getCurrentProcess != null) {
      final hProc = _getCurrentProcess!();
      if (_emptyWorkingSet != null) {
        _emptyWorkingSet!(hProc);
      }
      if (_setProcessWorkingSetSize != null) {
        _setProcessWorkingSetSize!(hProc, -1, -1);
      }
      _log.debug('Trimmed process working set memory');
    }
  }

  /// Starts periodic background memory optimization (every 30 seconds when resting/collapsed).
  static void startPeriodicMemoryTrim() {
    _periodicTrimTimer?.cancel();
    _periodicTrimTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!isExpanded) {
        trimMemory();
      }
    });
  }
}
