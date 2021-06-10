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
				case Error:
					DialogNode.error(text, title, timeout, callback);
				case Question:
					DialogNode.question(text, title, timeout, callback);
				case Entry:
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
	public static function init() {
		var homedir = js.node.Os.homedir() + '/';
		DialogNode.setCwd(homedir);

		var filename = switch (Sys.systemName()) {
			case 'Mac': 'datepicker.osa';
			case 'Windows': 'msgbox.vbs';
			default: '';
		}

		if (filename == '' || sys.FileSystem.exists(homedir + filename))
			return;

		var dialogsPath = js.Node.__dirname + '/../node_modules/dialog-node/';
		var src = dialogsPath + filename;
		var dst = homedir + filename;
		trace('Copying dialogs [$filename] to $dst');
		sys.io.File.copy(src, dst);
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
