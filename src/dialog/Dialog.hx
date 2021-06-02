package dialog;

import api.IdeckiaApi.DialogType;

typedef Callback = (code:UInt, returnValue:String, stdError:String) -> Void;

class Dialog {
	public static function show(type:DialogType, title:String, text:String) {
		return new js.lib.Promise((resolve, reject) -> {
			var timeout = 0;
			var callback = (code, returnValue, stdError) -> {
				if (code == 0)
					resolve(returnValue);
				else
					reject(stdError);
			};
			switch type {
				case DialogType.error:
					DialogNode.error(text, title, timeout, callback);
				case DialogType.question:
					DialogNode.question(text, title, timeout, callback);
				case DialogType.entry:
					DialogNode.entry(text, title, timeout, callback);
				default:
					DialogNode.info(text, title, timeout, callback);
			}
		});
	}

	/**
		Since the OS can't access to the pkg virtual filesystem to access the dialogs files,
		they must be in an accesible folder. I put them in the home directory of the current
		user. Then we can specify to the 'dialog-node' module where to look for those files.
	**/
	@:noCompletion
	public static function extractFiles() {
		var homedir = js.node.Os.homedir() + '/';
		var msgboxVbs = 'msgbox.vbs';
		var datepickerOsa = 'datepicker.osa';

		DialogNode.setCwd(homedir);

		inline function checkExists(filename:String) {
			return sys.FileSystem.exists(homedir + filename);
		}

		if (checkExists(msgboxVbs) && checkExists(datepickerOsa))
			return;

		var dialogsPath = js.Node.__dirname + '/../node_modules/dialog-node/';

		inline function copyFile(filename:String) {
			var src = dialogsPath + filename;
			var dst = homedir + filename;
			trace('Copying dialogs [$filename] to $dst');
			sys.io.File.copy(src, dst);
		}

		if (!checkExists(msgboxVbs))
			copyFile(msgboxVbs);
		if (!checkExists(datepickerOsa))
			copyFile(datepickerOsa);
	}
}

@:jsRequire('dialog-node')
extern class DialogNode {
	static function setCwd(dirname:String):Void;
	static function info(text:String, title:String, timeout:UInt, callback:Callback):Void;
	static function warn(text:String, title:String, timeout:UInt, callback:Callback):Void;
	static function error(text:String, title:String, timeout:UInt, callback:Callback):Void;
	static function question(text:String, title:String, timeout:UInt, callback:Callback):Void;
	static function entry(text:String, title:String, timeout:UInt, callback:Callback):Void;
	static function calendar(text:String, title:String, timeout:UInt, callback:Callback):Void;
	static function fileselect(text:String, title:String, timeout:UInt, callback:Callback):Void;
}
