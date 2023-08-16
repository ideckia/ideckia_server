package;

import managers.UpdateManager;
import websocket.WebSocketServer;
import api.internal.ServerApi;
import managers.ActionManager;
import managers.LayoutManager;
import managers.MsgManager;

using StringTools;

class Ideckia {
	@:v('ideckia.auto-launch-enabled:true')
	static var autoLaunchEnabled:Bool;

	@:v('ideckia.actions-path:actions')
	static var actionsPath:String;

	public static var dialog:api.dialog.IDialog;
	public static var mediaPlayer:api.media.IMediaPlayer;

	static public inline final CURRENT_VERSION = #if release Macros.getLastTagName() #else Macros.getGitCommitHash() #end;

	function new() {
		var appPath = getAppPath();
		dialog = try {
			var dialogsPath = appPath + '/dialogs';
			js.Syntax.code("var required = require({0})", dialogsPath);
			js.Syntax.code('new required.Dialog()');
		} catch (e:haxe.Exception) {
			Log.info('External dialogs implementation not found. Loading the fallback dialogs module.');
			new fallback.dialog.FallbackDialog();
		}
		UpdateManager.checkUpdates(appPath, 'dialogs');

		var iconPath = haxe.io.Path.join([appPath, 'icon.png']);
		if (sys.FileSystem.exists(iconPath))
			dialog.setDefaultOptions({windowIcon: iconPath});

		mediaPlayer = try {
			var mediaPath = appPath + '/media';
			js.Syntax.code("var required = require({0})", mediaPath);
			js.Syntax.code('new required.MediaPlayer()');
		} catch (e:haxe.Exception) {
			Log.info('External media player implementation not found. Loading the fallback media player module.');
			new fallback.media.FallbackMediaPlayer();
		}
		UpdateManager.checkUpdates(appPath, 'media');

		js.Node.process.on('uncaughtException', (error) -> {
			Log.error('There was an uncaughtException. Please restart the server.');
			Log.raw(error.stack);
		});
		js.Node.process.on('unhandledRejection', (error, promise) -> {
			Log.error('Rejection was not handled in the promise. Please restart the server.');
			Log.raw(error.stack);
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
		}).catchError(error -> {
			Log.error('Error with AutoLaunch');
			Log.raw(error.stack);
		});

		LayoutManager.load().finally(() -> {
			LayoutManager.watchForChanges();
			ActionManager.watchForChanges();

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
		});

		Tray.show(WebSocketServer.port);
	}

	public static function getAppPath(subPath:String = null) {
		var dir = [haxe.io.Path.directory(js.Node.process.execPath)];
		if (subPath != null)
			dir.push(subPath);
		return haxe.io.Path.join(dir);
	}

	public static function isPkg() {
		return js.Syntax.code('process.pkg != undefined');
	}

	public static function createNewAction(createActionDef:CreateActionDef) {
		var actionDestination = createActionDef.path;
		if (actionDestination == null || actionDestination == '')
			createActionDef.path = actionsPath;
		api.action.creator.ActionCreator.create(createActionDef);
	}

	static function main() {
		appropos.Appropos.init(getAppPath('app.props'));
		Log.init();
		UpdateManager.checkServerRelease();
		new Ideckia();
	}

	static public function exportDirs(dirNames:Array<String>) {
		LayoutManager.readLayout();
		switch LayoutManager.exportDirs(dirNames) {
			case Some(response):
				var filename = Ideckia.getAppPath('/dirs.export.json');
				sys.io.File.saveContent(filename, response.layout);
				Log.info('[${response.processedDirNames.join(',')}] successfully exported to [$filename].');
			case None:
				Log.info('Could not find [$dirNames] directories in the layout file.');
		};
	}
}
