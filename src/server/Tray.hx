using StringTools;

class Tray {
	inline static var TRAY_DIR_NAME = 'tray';

	static var exePath = '';
	static var iconPath = '';
	static var menuPath = '';
	static var aboutDialogPath = '';

	@:v('ideckia.client-path')
	static var clientPath:String;
	static var clientFullPath:String;

	public static function show(port:Int) {
		init();

		if (!sys.FileSystem.exists(exePath)) {
			Log.error('Tray executable [$exePath] not found.');
			return;
		}

		if (!sys.FileSystem.exists(menuPath)) {
			Log.error('Tray menu definition [$menuPath] not found.');
			return;
		}

		var menuDefContent = sys.io.File.getContent(menuPath);
		menuDefContent = menuDefContent.replace('::icon_path::', iconPath);
		menuDefContent = menuDefContent.replace('::port::', Std.string(port));
		menuDefContent = menuDefContent.replace('::client_disabled::', (sys.FileSystem.exists(clientFullPath)) ? '0' : '1');
		var menuDef:MenuDef = haxe.Json.parse(Lang.localizeAll(menuDefContent));

		menuDefContent = haxe.Json.stringify(menuDef).replace('"', '\\"');

		var trayProcess = js.node.ChildProcess.spawn(exePath, ['"$menuDefContent"'], {shell: true});

		trayProcess.stdout.on('data', d -> {
			var out = Std.string(d);
			var isEditor = out.startsWith('editor');
			var isLogs = out.startsWith('logs');
			var isClient = out.startsWith('client');
			if (isEditor || isLogs || isClient) {
				var launchCmd = switch Sys.systemName() {
					case "Linux": (isClient) ? '' : 'xdg-open';
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
				Log.debug('Opening ${out}');
				js.node.ChildProcess.spawn('$launchCmd $launchApp', {shell: true});
			} else if (out.startsWith('about')) {
				Ideckia.dialog.custom(aboutDialogPath);
			} else if (out.startsWith('quit')) {
				Sys.exit(0);
			}
		});
		trayProcess.stderr.on('data', e -> {
			Log.error('Tray error');
			Log.raw(e.stack);
		});
		trayProcess.on('error', err -> {
			Log.error('Tray error');
			Log.raw(err.stack);
		});
	}

	/**
		Since the OS can't access to the pkg virtual filesystem to access the tray executable,
		it must be in an accesible directory. I extract it to the root directory of Ideckia.
	**/
	@:noCompletion
	public static function init() {
		clientFullPath = if (clientPath == null) {
			null;
		} else if (js.node.Path.isAbsolute(clientPath)) {
			clientPath;
		} else {
			Ideckia.getAppPath(clientPath);
		}

		if (!Ideckia.isPkg())
			return;

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

		exePath = haxe.io.Path.join([trayDir, execFilename]);
		if (execFilename != '' && !sys.FileSystem.exists(exePath)) {
			var src = haxe.io.Path.join([js.Node.__dirname, TRAY_DIR_NAME, execFilename]);
			Log.info('Copying tray executable [$execFilename] to $exePath');
			sys.io.File.copy(src, exePath);
		}

		iconPath = haxe.io.Path.join([trayDir, iconFilename]);
		if (iconFilename != '' && !sys.FileSystem.exists(iconPath)) {
			var src = haxe.io.Path.join([js.Node.__dirname, TRAY_DIR_NAME, iconFilename]);
			Log.info('Copying tray icon [$iconFilename] to $iconPath');
			sys.io.File.copy(src, iconPath);
		}

		menuPath = haxe.io.Path.join([js.Node.__dirname, TRAY_DIR_NAME, 'menu_tpl.json']);

		var aboutFilename = 'about.json';
		var aboutContent = sys.io.File.getContent(haxe.io.Path.join([js.Node.__dirname, TRAY_DIR_NAME, 'about_tpl.json']));
		aboutContent = aboutContent.replace('::version::', Ideckia.CURRENT_VERSION);
		aboutDialogPath = haxe.io.Path.join([trayDir, aboutFilename]);
		Log.info('Copying "about" dialog [$aboutFilename] to $aboutDialogPath');
		sys.io.File.saveContent(aboutDialogPath, aboutContent);
	}
}

typedef MenuDef = {
	var icon:String;
	var menu:Array<MenuDefItem>;
}

typedef MenuDefItem = {
	var text:String;
	var disabled:UInt;
	var checked:UInt;
	var checkbox:UInt;
	var exit:UInt;
	var ?menu:Array<MenuDefItem>;
}
