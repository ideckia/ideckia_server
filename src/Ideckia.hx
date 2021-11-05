package;

import api.internal.ServerApi;
import dialog.Dialog;
import managers.ActionManager;
import managers.LayoutManager;
import managers.MsgManager;

using StringTools;

@:build(appropos.Appropos.generate())
class Ideckia {
	@:v('ideckia.log-level:ERROR')
	static var logLevel:String;

	@:v('ideckia.auto-launch-enabled:true')
	static var autoLaunchEnabled:Bool;

	@:v('ideckia.actions-path:actions')
	static var actionsPath:String;

	function new() {
		var autoLauncher = new AutoLaunch({
			name: 'Ideckia',
			path: js.Node.process.execPath
		});

		#if debug
		haxe.NativeStackTrace.wrapCallSite = js.Lib.require('source-map-support').wrapCallSite;
		#end

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

		var wsServer = new websocket.WebSocketServer();

		wsServer.onConnect = (connection) -> {
			MsgManager.send(connection, LayoutManager.currentDirForClient());
			LayoutManager.watchForChanges(connection);
		};

		wsServer.onMessage = (connection, msg) -> {
			Log.debug('Message received: $msg');
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

	static function main() {
		appropos.Appropos.init(getAppPath() + '/app.props');
		Log.level = logLevel;
		Dialog.init();

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
				var dirNamesArray = dirNames.split(',');
				LayoutManager.readLayout();
				switch LayoutManager.exportDirs(dirNamesArray) {
					case Some(response):
						var filename = Ideckia.getAppPath() + '/dirs.export.json';
						sys.io.File.saveContent(filename, response.layout);
						Log.info('[${response.processedDirNames.join(',')}] successfully exported to [$filename].');
					case None:
						Log.info('Could not find [$dirNames] directories in the layout file.');
				};
			} else {
				showHelp();
			}
		} else {
			new Ideckia();
		}
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
