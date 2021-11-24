package;

typedef Options = {
	var name:String;
	var ?path:String;
	var ?isHidden:Bool;
	var ?mac:{
		var ?useLaunchAgent:Bool;
	}
}

@:jsRequire('auto-launch')
extern class AutoLaunch {
	function new(options:Options);
	function enable():Void;
	function disable():Void;
	function isEnabled():js.lib.Promise<Bool>;
}
