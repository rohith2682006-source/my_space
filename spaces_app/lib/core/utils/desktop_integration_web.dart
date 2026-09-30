import 'dart:js_interop' as js;

@js.JS('window.openFileInNativeApp')
external js.JSBoolean _jsOpenFile(js.JSString url, js.JSString filename);

@js.JS('window.systemShareApp')
external js.JSPromise<js.JSBoolean> _jsSystemShare(
    js.JSString title, js.JSString text, js.JSString url);

void openFileInWeb(String fileUrl, String fileName) {
  _jsOpenFile(fileUrl.toJS, fileName.toJS);
}

Future<bool> shareInWeb(String title, String text, String shareUrl) async {
  final promise = _jsSystemShare(title.toJS, text.toJS, shareUrl.toJS);
  final js.JSBoolean res = await promise.toDart;
  return res.toDart;
}
