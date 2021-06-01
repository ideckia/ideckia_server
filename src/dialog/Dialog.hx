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
