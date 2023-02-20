package;

using StringTools;

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

	static var logStream:js.node.fs.WriteStream;

	@:v('ideckia.logs-path:logs')
	static var logsPath:String;

	public static function getLogsPath() {
		if (js.node.Path.isAbsolute(logsPath))
			return logsPath;
		return Ideckia.getAppPath(logsPath);
	}

	public static function init() {
		var time = DateTools.format(Date.now(), '%F %T').replace(':', '.');
		var logsPath = getLogsPath();
		if (!sys.FileSystem.exists(logsPath))
			sys.FileSystem.createDirectory(logsPath);
		var logFile = haxe.io.Path.join([logsPath, '$time.log']);
		sys.io.File.saveContent(logFile, '');

		logStream = js.node.Fs.createWriteStream(logFile);
		logStream.on('error', (error) -> {
			trace('An error occured while writing to the file. Error: ${error.message}');
		});
	}

	public static function debug(data:Dynamic, ?posInfos:haxe.PosInfos) {
		var logData = getLogData('DEBUG', data, posInfos);
		toFile(logData);
		if (level > DEBUG) {
			return;
		}
		toConsole(logData);
	}

	public static function info(data:Dynamic, ?posInfos:haxe.PosInfos) {
		var logData = getLogData('INFO', data, posInfos);
		toFile(logData);
		if (level > INFO) {
			return;
		}
		toConsole(logData);
	}

	public static function warn(data:Dynamic, ?posInfos:haxe.PosInfos) {
		var logData = getLogData('WARN', data, posInfos);
		toFile(logData);
		if (level > WARN) {
			return;
		}
		toConsole(logData);
	}

	public static function error(data:Dynamic, ?posInfos:haxe.PosInfos) {
		var logData = getLogData('ERROR', data, posInfos);
		toFile(logData);
		if (level > ERROR) {
			return;
		}
		toConsole(logData);
	}

	static private function getLogData(levelString:String, data:Dynamic, posInfos:haxe.PosInfos) {
		var time = DateTools.format(Date.now(), '%H:%M:%S');
		var filePath = posInfos.fileName;
		var filename = StringTools.replace(filePath.substr(filePath.lastIndexOf('/') + 1), '.hx', '');
		return '$time [$levelString]-[$filename.${posInfos.methodName}:${posInfos.lineNumber}]: $data'.replace('\n', '\\n');
	}

	static private function toFile(data:String) {
		logStream.write(data + '\n');
	}

	static private function toConsole(data:String) {
		Sys.println(data);
	}
}
