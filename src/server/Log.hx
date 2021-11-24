package;

enum abstract Level(Int) from Int to Int {
	var DEBUG;
	var INFO;
	var WARN;
	var ERROR;

	@:from public static function fromString(s:String):Level {
		if (s == null)
			return ERROR;

		return switch s.toUpperCase() {
			case 'DEBUG': DEBUG;
			case 'INFO': INFO;
			case 'WARN': WARN;
			default: ERROR;
		}
	}

	@:op(A > B) static function gt(a:Level, b:Level):Bool;
}

class Log {
	public static var level:Level = ERROR;

	#if sys
	static var logger:Dynamic->Void = Sys.println;
	#elseif js
	static var logger:Dynamic->Void = js.html.Console.log;
	#end

	public static function debug(data:Dynamic, ?posInfos:haxe.PosInfos) {
		if (level > DEBUG) {
			return;
		}
		doLog('DEBUG', data, posInfos);
	}

	public static function info(data:Dynamic, ?posInfos:haxe.PosInfos) {
		if (level > INFO) {
			return;
		}
		doLog('INFO', data, posInfos);
	}

	public static function warn(data:Dynamic, ?posInfos:haxe.PosInfos) {
		if (level > WARN) {
			return;
		}
		doLog('WARN', data, posInfos);
	}

	public static function error(data:Dynamic, ?posInfos:haxe.PosInfos) {
		if (level > ERROR) {
			return;
		}
		doLog('ERROR', data, posInfos);
	}

	static private function doLog(levelString:String, data:Dynamic, posInfos:haxe.PosInfos) {
        var time = DateTools.format(Date.now(), '%H:%M:%S');
		logger('$time [$levelString] - [${posInfos.fileName}.${posInfos.methodName}:${posInfos.lineNumber}]: $data');
	}
}
