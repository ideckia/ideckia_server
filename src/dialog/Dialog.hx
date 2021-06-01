package dialog;

typedef Callback = (code:UInt, returnValue:String, stdError:String) -> Void;

@:jsRequire('dialog-node')
extern class Dialog {
    static function setCwd(dirname:String):Void;
    static function info(text:String, title:String, timeout:UInt, callback:Callback):Void;
    static function warn(text:String, title:String, timeout:UInt, callback:Callback):Void;
    static function error(text:String, title:String, timeout:UInt, callback:Callback):Void;
    static function question(text:String, title:String, timeout:UInt, callback:Callback):Void;
    static function entry(text:String, title:String, timeout:UInt, callback:Callback):Void;
    static function calendar(text:String, title:String, timeout:UInt, callback:Callback):Void;
    static function fileselect(text:String, title:String, timeout:UInt, callback:Callback):Void;
}