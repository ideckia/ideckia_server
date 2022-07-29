import api.dialog.Dialog;
import api.dialog.DialogTypes.Color;
import api.dialog.DialogTypes.FileFilter;
import api.dialog.DialogTypes.WindowOptions;
import js.lib.Promise;

@:keep
class FallbackDialog implements Dialog {
	static inline var FALLBACK_MESSAGE = 'No valid api.dialog.Dialog implementation found. Please probide an implementation as defined here []';

	public function new() {
		trace('Called dialog.$new function.');
		trace(FALLBACK_MESSAGE);
	}

	public function setDefaultOptions(options:WindowOptions) {
		trace('Called dialog.$setDefaultOptions function.');
		trace(FALLBACK_MESSAGE);
	}

	public function notify(title:String, text:String, ?options:WindowOptions) {
		trace('Called dialog.$notify function.');
		trace(FALLBACK_MESSAGE);
	}

	public function info(title:String, text:String, ?options:WindowOptions) {
		trace('Called dialog.$info function.');
		trace(FALLBACK_MESSAGE);
	}

	public function warning(title:String, text:String, ?options:WindowOptions) {
		trace('Called dialog.$warning function.');
		trace(FALLBACK_MESSAGE);
	}

	public function error(title:String, text:String, ?options:WindowOptions) {
		trace('Called dialog.$error function.');
		trace(FALLBACK_MESSAGE);
	}

	public function question(title:String, text:String, ?options:WindowOptions):Promise<Bool> {
		trace('Called dialog.$question function.');
		trace(FALLBACK_MESSAGE);
		return Promise.resolve(true);
	}

	public function selectFile(title:String, isDirectory:Bool = false, multiple:Bool = false, ?fileFilter:FileFilter,
			?options:WindowOptions):Promise<Array<String>> {
		trace('Called dialog.$selectFile function.');
		trace(FALLBACK_MESSAGE);
		return Promise.resolve(['file0path', 'file1path']);
	}

	public function saveFile(title:String, ?saveName:String, ?fileFilter:FileFilter, ?options:WindowOptions):Promise<String> {
		trace('Called dialog.$saveFile function.');
		trace(FALLBACK_MESSAGE);
		return Promise.resolve('filepath');
	}

	public function entry(title:String, text:String, placeholder:String = '', ?options:WindowOptions):Promise<String> {
		trace('Called dialog.$entry function.');
		trace(FALLBACK_MESSAGE);
		return Promise.resolve(placeholder);
	}

	public function password(title:String, text:String, showUsername:Bool = false, ?options:WindowOptions):Promise<Array<String>> {
		trace('Called dialog.$password function.');
		trace(FALLBACK_MESSAGE);
		return Promise.resolve(['username', 'password']);
	}

	public function progress(title:String, text:String, pulsate:Bool = false, autoClose:Bool = true, ?options:WindowOptions):Progress {
		trace('Called dialog.$progress function.');
		trace(FALLBACK_MESSAGE);
		return new FallbackProgress();
	}

	public function color(title:String, ?initialColor:String, palette:Bool = false, ?options:WindowOptions):Promise<Color> {
		trace('Called dialog.$color function.');
		trace(FALLBACK_MESSAGE);
		inline function rndColorComp()
			return Std.int(Math.random() * 255);
		return Promise.resolve(new Color({red: rndColorComp(), green: rndColorComp(), blue: rndColorComp()}));
	}

	public function calendar(title:String, text:String, ?year:UInt, ?month:UInt, ?day:UInt, ?dateFormat:String, ?options:WindowOptions):Promise<String> {
		trace('Called dialog.$calendar function.');
		trace(FALLBACK_MESSAGE);
		return Promise.resolve(Date.now().toString());
	}

	public function list(title:String, text:String, columnHeader:String, values:Array<String>, multiple:Bool = false,
			?options:WindowOptions):Promise<Array<String>> {
		trace('Called dialog.$list function.');
		trace(FALLBACK_MESSAGE);
		return Promise.resolve(['item0', 'item1']);
	}
}

@:keep
class FallbackProgress implements Progress {
	public function new() {}

	public function progress(percentage:UInt) {}
}
