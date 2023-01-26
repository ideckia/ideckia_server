package;

import websocket.WebSocketServer;
import api.internal.ServerApi;
import managers.ActionManager;
import managers.LayoutManager;
import managers.MsgManager;
import tink.semver.Version;

using StringTools;

@:build(appropos.Appropos.generate())
class Ideckia {
	@:v('ideckia.log-level:ERROR')
	static var logLevel:String;

	@:v('ideckia.auto-launch-enabled:true')
	static var autoLaunchEnabled:Bool;

	@:v('ideckia.actions-path:actions')
	static var actionsPath:String;

	public static var dialog:api.dialog.IDialog;
	public static var mediaPlayer:api.media.IMediaPlayer;

	static public inline final CURRENT_VERSION = #if release Macros.getLastTagName() #else Macros.getGitCommitHash() #end;

	function new() {
		dialog = try {
			var dialogsPath = getAppPath() + '/dialogs';
			js.Syntax.code("var required = require({0})", dialogsPath);
			js.Syntax.code('new required.Dialog()');
		} catch (e:haxe.Exception) {
			Log.info('External dialogs implementation not found. Loading the fallback dialogs module.');
			new fallback.dialog.FallbackDialog();
		}
		var iconPath = haxe.io.Path.join([getAppPath(), 'icon.png']);
		if (sys.FileSystem.exists(iconPath))
			dialog.setDefaultOptions({windowIcon: iconPath});
		mediaPlayer = try {
			var mediaPath = getAppPath() + '/media';
			js.Syntax.code("var required = require({0})", mediaPath);
			js.Syntax.code('new required.MediaPlayer()');
		} catch (e:haxe.Exception) {
			Log.info('External media player implementation not found. Loading the fallback media player module.');
			new fallback.media.FallbackMediaPlayer();
		}

		js.Node.process.on('uncaughtException', (error) -> {
			Log.error('There was an uncaughtException. Please restart the server.');
			Sys.println(error);
		});
		js.Node.process.on('unhandledRejection', (error, promise) -> {
			Log.error('Rejection was not handled in the promise. Please restart the server.');
			Sys.println(error);
		});

		var autoLauncher = new AutoLaunch({
			name: 'Ideckia',
			path: js.Node.process.execPath
		});

		autoLauncher.isEnabled().then((isEnabled) -> {
			switch [isEnabled, autoLaunchEnabled] {
				case [false, false] | [true, true]:
					return;
				case [false, true]:
					Log.info('Enabling auto-launch.');
					autoLauncher.enable();
				case [true, false]:
					Log.info('Disabling auto-launch.');
					autoLauncher.disable();
			}
		}).catchError((error) -> {
			Log.error('Error with AutoLaunch: $error');
		});

		LayoutManager.load();
		LayoutManager.watchForChanges();

		var wsServer = new WebSocketServer();

		wsServer.onConnect = (connection) -> {
			MsgManager.send(connection, LayoutManager.currentDirForClient());
		};

		wsServer.onMessage = (connection, msg) -> {
			Log.debug('Message received: ${Std.string(msg).substring(0, 1000)}');
			MsgManager.route(connection, msg);
		}

		wsServer.onClose = (connection, reasonCode, description) -> {
			Log.info('Closing connection [code=$reasonCode]: $description');
			connection.dispose();
		}
	}

	public static function getAppPath() {
		return haxe.io.Path.directory(js.Node.process.execPath);
	}

	static function checkNewerRelease() {
		var http = new haxe.http.HttpNodeJs('https://api.github.com/repos/ideckia/ideckia_server/releases');
		http.addHeader("User-Agent", "ideckia");

		if (CURRENT_VERSION.indexOf(Macros.DEV_COMMIT_PREFIX) != -1)
			return;

		var currentVersion = switch Version.parse(CURRENT_VERSION.replace('v', '')) {
			case Success(ver):
				ver;
			case Failure(_):
				new Version(0, 0, 0);
		};

		http.onError = (e) -> trace('Error checking the releases: ' + e);
		http.onData = (data) -> {
			var releases:Array<{tag_name:String, prerelease:Bool, html_url:String}> = haxe.Json.parse(data);
			var lastReleaseVersion:Version = new Version(0, 0, 0);
			var releaseNumber:String;
			var lastReleaseUrl:String = '';
			for (r in releases) {
				if (r.prerelease)
					continue;

				releaseNumber = r.tag_name.replace('v', '');
				switch Version.parse(releaseNumber) {
					case Success(releaseVersion):
						if (releaseVersion > lastReleaseVersion) {
							lastReleaseVersion = releaseVersion;
							lastReleaseUrl = r.html_url;
						}
					case Failure(_):
				};
			}

			if (lastReleaseVersion > currentVersion)
				Log.info('New ideckia version [$lastReleaseVersion] is available for download. Get it from $lastReleaseUrl');
		};

		http.request();
	}

	static function main() {
		appropos.Appropos.init(getAppPath() + '/app.props');
		Log.level = logLevel;
		checkNewerRelease();

		var args = Sys.args();
		if (args.length > 0) {
			var newActionIndex = args.indexOf('--new-action');
			var runActionIndex = args.indexOf('--run-action');
			var appendLayoutIndex = args.indexOf('--append-layout');
			var exportDirsIndex = args.indexOf('--export-dirs');

			if (newActionIndex != -1) {
				api.action.creator.ActionCreator.create(actionsPath);
			} else if (runActionIndex != -1) {
				var param = args[runActionIndex + 1];
				var state:ServerState;
				if (param.endsWith('.json')) {
					Log.debug('Reading file: [$param]');
					state = haxe.Json.parse(sys.io.File.getContent(param));
				} else {
					state = {
						actions: [
							{
								enabled: true,
								name: param,
								props: {}
							}
						]
					};
				}

				ActionManager.runAction(state);
			} else if (appendLayoutIndex != -1) {
				var newLayoutFile = args[appendLayoutIndex + 1];
				var newLayout:Layout = tink.Json.parse(sys.io.File.getContent(sys.FileSystem.absolutePath(Ideckia.getAppPath() + '/' + newLayoutFile)));
				LayoutManager.readLayout();
				LayoutManager.appendLayout(newLayout);
				sys.io.File.saveContent(LayoutManager.getLayoutPath(), LayoutManager.exportLayout());
			} else if (exportDirsIndex != -1) {
				var dirNames = args[exportDirsIndex + 1];
				exportDirs(dirNames.split(','));
			} else {
				showHelp();
			}
		} else {
			new Ideckia();
		}
	}

	static public function exportDirs(dirNames:Array<String>) {
		LayoutManager.readLayout();
		switch LayoutManager.exportDirs(dirNames) {
			case Some(response):
				var filename = Ideckia.getAppPath() + '/dirs.export.json';
				sys.io.File.saveContent(filename, response.layout);
				Log.info('[${response.processedDirNames.join(',')}] successfully exported to [$filename].');
			case None:
				Log.info('Could not find [$dirNames] directories in the layout file.');
		};
	}

	static function showHelp() {
		trace("Ideckia CLI usage:");
		trace("	If no argumet is given, the server runs normally.");
		trace("	Accepted arguments:");
		trace("	--help: You are here.");
		trace("	--new-action: Creates a new action from a template (Haxe or Javascript).");
		trace("	--append-layout: Append a layout directories and icons from a given JSON file parameter.");
		trace("	--export-dirs: Export the directories named given by parameters (separated by commas).");
		trace("	--run-action: Executes an action from actions path. The parameter can be the action name *or* an action properties Json file, only one. The argument type will be evaluated from the extension of the parameter.");
		trace("		action-name: Name of the action to run.");
		trace("		action-props.json: Json file path with the action properties");
	}
}
