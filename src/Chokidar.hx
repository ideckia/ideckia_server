package;

@:jsRequire('chokidar')
extern class Chokidar {
	static function watch(path:String):js.node.fs.FSWatcher;
}
