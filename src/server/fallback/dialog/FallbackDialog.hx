package fallback.dialog;

import api.dialog.DialogTypes.IdValue;
import api.dialog.IDialog;
import api.dialog.DialogTypes.Color;
import api.dialog.DialogTypes.FileFilter;
import api.dialog.DialogTypes.WindowOptions;
import js.lib.Promise;
import haxe.ds.Option;

class FallbackDialog implements IDialog {
	static inline var FALLBACK_MESSAGE = 'Using a very basic implementation of api.dialog.IDialog implementation found. Please provide an implementation as defined here [https://github.com/ideckia/ideckia_api/blob/develop/api/dialog/IDialog.hx]';

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
			?options:WindowOptions):Promise<Option<Array<String>>> {
		trace(FALLBACK_MESSAGE);
		return new js.lib.Promise((resolve, reject) -> {
			Dialog.show(FileSelect, title, 'Select a file').then(resp -> resolve(Some([resp]))).catchError(reject);
		});
	}

	public function saveFile(title:String, ?saveName:String, ?fileFilter:FileFilter, ?options:WindowOptions):Promise<Option<String>> {
		trace(FALLBACK_MESSAGE);
		return new js.lib.Promise((resolve, reject) -> {
			Dialog.show(FileSelect, title, "Save a file").then(resp -> resolve(Some(resp))).catchError(reject);
		});
	}

	public function entry(title:String, text:String, placeholder:String = '', ?options:WindowOptions):Promise<Option<String>> {
		trace(FALLBACK_MESSAGE);
		return new js.lib.Promise((resolve, reject) -> {
			Dialog.show(Entry, title, text).then(resp -> resolve(Some(resp))).catchError(reject);
		});
	}

	public function password(title:String, text:String, showUsername:Bool = false,
			?options:WindowOptions):Promise<Option<{username:String, password:String}>> {
		trace(FALLBACK_MESSAGE);
		return new js.lib.Promise((resolve, reject) -> {
			Dialog.show(Entry, title, text).then(resp -> resolve(Some({username: null, password: resp}))).catchError(reject);
		});
	}

	public function progress(title:String, text:String, autoClose:Bool = true, ?options:WindowOptions):Progress {
		trace(FALLBACK_MESSAGE);
		return new FallbackProgress();
	}

	public function color(title:String, ?initialColor:String, ?options:WindowOptions):Promise<Option<Color>> {
		trace(FALLBACK_MESSAGE);
		inline function rndColorComp()
			return Std.int(Math.random() * 255);
		return Promise.resolve(Some(new Color({red: rndColorComp(), green: rndColorComp(), blue: rndColorComp()})));
	}

	public function calendar(title:String, text:String, ?year:UInt, ?month:UInt, ?day:UInt, ?dateFormat:String,
			?options:WindowOptions):Promise<Option<String>> {
		trace(FALLBACK_MESSAGE);
		return Promise.resolve(Some(Date.now().toString()));
	}

	public function list(title:String, text:String, columnHeader:String, values:Array<String>, multiple:Bool = false,
			?options:WindowOptions):Promise<Option<Array<String>>> {
		trace(FALLBACK_MESSAGE);
		return Promise.resolve(Some(values));
	}

	public function custom(definitionPath:String):api.IdeckiaApi.Promise<Option<Array<IdValue<String>>>> {
		throw new haxe.exceptions.NotImplementedException();
	}
}

@:keep
class FallbackProgress implements Progress {
	public function new() {}

	public function progress(percentage:UInt) {}
}
