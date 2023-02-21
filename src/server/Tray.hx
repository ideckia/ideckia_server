using StringTools;

class Tray {
	inline static var TRAY_DIR_NAME = 'tray';

	static var trayExePath = '';
	static var trayIconPath = '';

	@:v('ideckia.client-path')
	static var clientPath:String;
	static var clientFullPath:String;

	public static function show(port:Int) {
		init();

		if (!sys.FileSystem.exists(trayExePath)) {
			Log.error('Tray executable [$trayExePath] not found.');
			return;
		}

		var args = [trayIconPath, Std.string(port)];
		if (clientFullPath != null && sys.FileSystem.exists(clientFullPath))
			args.push(clientFullPath);

		var trayProcess = js.node.ChildProcess.spawn(trayExePath, args, {shell: true});

		trayProcess.stdout.on('data', d -> {
			var out = Std.string(d);
			var isEditor = out.startsWith('editor');
			var isLogs = out.startsWith('logs');
			var isClient = out.startsWith('client');
			if (isEditor || isLogs || isClient) {
				var launchCmd = switch Sys.systemName() {
					case "Linux": 'xdg-open';
					case "Mac": 'open';
					case "Windows": 'start';
					case _: '';
				};

				var launchApp = if (isEditor) {
					'http://localhost:${port}/editor';
				} else if (isLogs) {
					Log.getLogsPath();
				} else {
					clientFullPath;
				}
				js.node.ChildProcess.spawn('$launchCmd $launchApp', {shell: true});
			} else if (out.startsWith('quit')) {
				Sys.exit(0);
			}
		});
		trayProcess.stderr.on('data', e -> {
			Log.error('Tray error');
			Log.raw(e);
		});
		trayProcess.on('error', err -> {
			Log.error('Tray error');
			Log.raw(err);
		});
	}

	/**
		Since the OS can't access to the pkg virtual filesystem to access the tray executable,
		it must be in an accesible directory. I extract it to the root directory of Ideckia.
	**/
	@:noCompletion
	public static function init() {
		var trayDir = Ideckia.getAppPath(TRAY_DIR_NAME);

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

		clientFullPath = if (clientPath == null) {
			null;
		} else if (js.node.Path.isAbsolute(clientPath)) {
			clientPath;
		} else {
			Ideckia.getAppPath(clientPath);
		}
	}
}
