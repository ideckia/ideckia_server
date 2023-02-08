using StringTools;

class Tray {
	inline static var TRAY_DIR_NAME = 'tray';

	static var trayExePath = '';
	static var trayIconPath = '';

	public static function show(port:Int) {
		init();

		if (!sys.FileSystem.exists(trayExePath)) {
			Log.error('Tray executable [$trayExePath] not found.');
			return;
		}

		var args = [trayIconPath, Std.string(port)];

		var trayProcess = js.node.ChildProcess.spawn(trayExePath, args, {shell: true});

		trayProcess.stdout.on('data', d -> {
			var out = Std.string(d);
			if (out.startsWith('editor')) {
				var launchCmd = switch Sys.systemName() {
					case "Linux": 'xdg-open';
					case "Mac": 'open';
					case "Windows": 'start';
					case _: '';
				};
				js.node.ChildProcess.spawn('$launchCmd http://localhost:${port}/editor', {shell: true});
			} else if (out.startsWith('quit')) {
				Sys.exit(0);
			}
		});
		trayProcess.stderr.on('data', e -> {
			Log.error('Tray error: $e');
		});
		trayProcess.on('error', err -> {
			Log.error('Tray error: $err');
		});
	}

	/**
		Since the OS can't access to the pkg virtual filesystem to access the tray executable,
		it must be in an accesible directory. I extract it to the root directory of Ideckia.
	**/
	@:noCompletion
	public static function init() {
		var trayDir = haxe.io.Path.join([Ideckia.getAppPath(), TRAY_DIR_NAME]);

		if (!sys.FileSystem.exists(trayDir))
			sys.FileSystem.createDirectory(trayDir);

		var execFilename = '';
		var iconFilename = '';
		switch (Sys.systemName()) {
			case 'Mac':
				execFilename = 'ideckia_tray_macos';
				iconFilename = 'icon.png';
			case 'Linux':
				execFilename = 'ideckia_tray_linux';
				iconFilename = 'icon.png';
			case 'Windows':
				execFilename = 'ideckia_tray.exe';
				iconFilename = 'icon.ico';
			default:
				'';
		}

		trayExePath = haxe.io.Path.join([trayDir, execFilename]);
		if (execFilename != '' && !sys.FileSystem.exists(trayExePath)) {
			var src = haxe.io.Path.join([js.Node.__dirname, TRAY_DIR_NAME, execFilename]);
			Log.info('Copying tray executable [$execFilename] to $trayExePath');
			sys.io.File.copy(src, trayExePath);
		}

		trayIconPath = haxe.io.Path.join([trayDir, iconFilename]);
		if (iconFilename != '' && !sys.FileSystem.exists(trayIconPath)) {
			var src = haxe.io.Path.join([js.Node.__dirname, TRAY_DIR_NAME, iconFilename]);
			Log.info('Copying tray icon [$iconFilename] to $trayIconPath');
			sys.io.File.copy(src, trayIconPath);
		}
	}
}
