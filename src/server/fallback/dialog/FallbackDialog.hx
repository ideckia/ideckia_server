package fallback.dialog;

import api.dialog.IDialog;
import api.dialog.DialogTypes.Color;
import api.dialog.DialogTypes.FileFilter;
import api.dialog.DialogTypes.WindowOptions;
import js.lib.Promise;

@:keep
class FallbackDialog implements IDialog {
	static inline var FALLBACK_MESSAGE = 'Using a very basic implementation of api.dialog.IDialog implementation found. Please probide an implementation as defined here [https://github.com/ideckia/ideckia_api/blob/develop/api/dialog/IDialog.hx]';

	public function new() {
		Dialog.init();
		trace(FALLBACK_MESSAGE);
	}

	public function setDefaultOptions(options:WindowOptions) {
		trace(FALLBACK_MESSAGE);
	}

	public function notify(title:String, text:String, ?options:WindowOptions) {
		trace(FALLBACK_MESSAGE);
		Dialog.show(Info, title, text);
	}

	public function info(title:String, text:String, ?options:WindowOptions) {
		trace(FALLBACK_MESSAGE);
		Dialog.show(Info, title, text);
	}

	public function warning(title:String, text:String, ?options:WindowOptions) {
		trace(FALLBACK_MESSAGE);
		Dialog.show(Warning, title, text);
	}

	public function error(title:String, text:String, ?options:WindowOptions) {
		trace(FALLBACK_MESSAGE);
		Dialog.show(Error, title, text);
	}

	public function question(title:String, text:String, ?options:WindowOptions):Promise<Bool> {
		trace(FALLBACK_MESSAGE);
		return new js.lib.Promise((resolve, reject) -> {
			Dialog.show(Question, title, text).then(ok -> resolve(ok == 'OK')).catchError(reject);
		});
	}

	public function selectFile(title:String, isDirectory:Bool = false, multiple:Bool = false, ?fileFilter:FileFilter,
			?options:WindowOptions):Promise<Array<String>> {
		trace(FALLBACK_MESSAGE);
		return new js.lib.Promise((resolve, reject) -> {
			Dialog.show(FileSelect, title, 'Select a file').then(resp -> resolve([resp])).catchError(reject);
		});
	}

	public function saveFile(title:String, ?saveName:String, ?fileFilter:FileFilter, ?options:WindowOptions):Promise<String> {
		trace(FALLBACK_MESSAGE);
		return Dialog.show(FileSelect, title, "Save a file");
	}

	public function entry(title:String, text:String, placeholder:String = '', ?options:WindowOptions):Promise<String> {
		trace(FALLBACK_MESSAGE);
		return Dialog.show(Entry, title, text);
	}

	public function password(title:String, text:String, showUsername:Bool = false, ?options:WindowOptions):Promise<Array<String>> {
		trace(FALLBACK_MESSAGE);
		return new js.lib.Promise((resolve, reject) -> {
			Dialog.show(Entry, title, text).then(resp -> resolve([resp])).catchError(reject);
		});
	}

	public function progress(title:String, text:String, pulsate:Bool = false, autoClose:Bool = true, ?options:WindowOptions):Progress {
		trace(FALLBACK_MESSAGE);
		return new FallbackProgress();
	}

	public function color(title:String, ?initialColor:String, palette:Bool = false, ?options:WindowOptions):Promise<Color> {
		trace(FALLBACK_MESSAGE);
		inline function rndColorComp()
			return Std.int(Math.random() * 255);
		return Promise.resolve(new Color({red: rndColorComp(), green: rndColorComp(), blue: rndColorComp()}));
	}

	public function calendar(title:String, text:String, ?year:UInt, ?month:UInt, ?day:UInt, ?dateFormat:String, ?options:WindowOptions):Promise<String> {
		trace(FALLBACK_MESSAGE);
		return Promise.resolve(Date.now().toString());
	}

	public function list(title:String, text:String, columnHeader:String, values:Array<String>, multiple:Bool = false,
			?options:WindowOptions):Promise<Array<String>> {
		trace(FALLBACK_MESSAGE);
		return Promise.resolve(['item0', 'item1']);
	}
}

@:keep
class FallbackProgress implements Progress {
	public function new() {}

	public function progress(percentage:UInt) {}
}
