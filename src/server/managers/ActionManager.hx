package managers;

import haxe.ds.Option;
import js.node.Require;

using api.IdeckiaApi;
using api.internal.ServerApi;
using StringTools;

class ActionManager {
	@:v('ideckia.actions-path:actions')
	static var actionsPath:String;

	static var clientActions:Map<StateId, Array<IdeckiaAction>>;
	static var actionDescriptors:Array<ActionDescriptor>;
	static var isWatching:Bool = false;

	public static function getActionsPath() {
		if (js.node.Path.isAbsolute(actionsPath))
			return actionsPath;
		return Ideckia.getAppPath(actionsPath);
	}

	public static function loadAndInitAction(itemId:ItemId, state:ServerState, addToCache:Bool = true):Option<Array<IdeckiaAction>> {
		Log.debug('Load actions from item [$itemId] / state [id=${state.id}] [text=${state.text}], [icon=${(state.icon == null) ? null : state.icon.substring(0, 50) + "..."}]');
		var actions = state.actions;
		if (actions == null || actions.length == 0)
			return None;

		var retActions = [];
		var actionsBasePath = getActionsPath();
		for (action in actions) {
			try {
				var name = action.name;
				var idkServer:IdeckiaServer = {
					log: {
						error: actionLog.bind(Log.error, name),
						debug: actionLog.bind(Log.debug, name),
						info: actionLog.bind(Log.info, name)
					},
					dialog: Ideckia.dialog,
					mediaPlayer: Ideckia.mediaPlayer,
					updateClientState: ClientManager.fromActionToClient.bind(itemId, name)
				};
				if (!action.enabled) {
					continue;
				}
				var actionPath = actionsBasePath + '/$name';
				UpdateManager.checkUpdates(actionsBasePath, name);
				var ideckiaAction:IdeckiaAction = requireAction(actionPath);

				var propFieldValue;
				var sharedEReg = ~/\$([\w0-9.\-_]+)/g;
				var sharedName;
				for (field in Reflect.fields(action.props)) {
					propFieldValue = Reflect.field(action.props, field);
					if (sharedEReg.match(Std.string(propFieldValue))) {
						sharedName = sharedEReg.matched(1);
						switch LayoutManager.getSharedValue(sharedName) {
							case Some(sharedValue):
								Log.debug('Replacing shared value [$sharedName] by [$sharedValue] in [$name] action.');
								Reflect.setField(action.props, field, sharedValue);
							case None:
								Log.error('Not found shared value with name [$sharedName]');
						}
					}
				}

				state.textSize = state.textSize == null ? LayoutManager.layout.textSize : state.textSize;
				ideckiaAction.setup(action.props, idkServer);
				ideckiaAction.init(state).then(newState -> {
					if (newState != null) {
						state.text = newState.text;
						state.textColor = newState.textColor;
						state.textSize = newState.textSize;
						state.icon = newState.icon;
						state.bgColor = newState.bgColor;
					}
				}).catchError((error) -> {
					Log.error('Error initializing [${name}] action of the state [id=${state.id}]');
					Log.raw(error.stack);
				});

				retActions.push(ideckiaAction);
			} catch (e:haxe.Exception) {
				Log.error('Error creating [${action.name}] action: ${e.message}');
				Log.raw(e.stack);
			}
		}

		if (addToCache)
			clientActions.set(state.id, retActions);
		return Some(retActions);
	}

	public static function initClientActions() {
		clientActions = new Map();
		actionDescriptors = null;

		for (i in LayoutManager.getAllItems()) {
			switch i.kind {
				case States(_, list):
					for (state in list)
						loadAndInitAction(i.id, state);
				default:
			}
		}
	}

	public static function unloadActions() {
		var normalizedActionsPath = haxe.io.Path.normalize(getActionsPath()).toLowerCase();
		for (module in Require.cache) {
			if (module == null || !haxe.io.Path.normalize(module.id.toLowerCase()).startsWith(normalizedActionsPath))
				continue;
			if (module.id.endsWith('.js')) {
				Log.debug('Unloading [${module.id}]');
				Require.cache.remove(module.id);
			}
		}
	}

	public static function watchForChanges() {
		if (isWatching)
			return;

		Chokidar.watch(ActionManager.getActionsPath()).on('change', (path) -> {
			actionDescriptors = null;
			var actionDir = haxe.io.Path.directory(path);
			var actionName = haxe.io.Path.withoutDirectory(actionDir);
			Log.info('Change detected in [$actionName] action, reloading...');
			unloadActions();
			initClientActions();
		});

		isWatching = true;
	}

	static function actionLog(log:(data:Dynamic, ?posInfos:haxe.PosInfos) -> Void, actionName:String, v:Dynamic, ?posInfos:haxe.PosInfos) {
		log('[$actionName]: $v', posInfos);
	}

	public static function getEditorActionDescriptors() {
		var actionPath = getActionsPath();
		if (actionDescriptors == null) {
			actionDescriptors = [];
			var desc:ActionDescriptor;
			var cId = 0, action:IdeckiaAction;
			for (c in sys.FileSystem.readDirectory(actionPath)) {
				if (!sys.FileSystem.exists('$actionPath/$c/index.js') || c.startsWith('_'))
					continue;

				action = requireAction('$actionPath/$c');
				try {
					desc = action.getActionDescriptor();
					desc.id = cId++;
					actionDescriptors.push(desc);
				} catch (e:haxe.Exception) {
					Log.error('Error reading action descriptor of $c: ${e.message}');
					Log.raw(e.stack);
				}
			}
		}

		var presetsPath;
		for (desc in actionDescriptors) {
			presetsPath = '$actionPath/${desc.name}/presets.json';
			desc.presets = (sys.FileSystem.exists(presetsPath)) ? haxe.Json.parse(sys.io.File.getContent(presetsPath)) : [];
		}

		return actionDescriptors;
	}

	public static function getActionByStateId(stateId:StateId) {
		if (clientActions == null || stateId == null || !clientActions.exists(stateId))
			return None;

		return Some(clientActions.get(stateId));
	}

	public static function runAction(state:ServerState) {
		switch loadAndInitAction(new ItemId(-1), state, false) {
			case Some(actions):
				for (action in actions)
					action.execute(state);
			case None:
				Log.error('the action is null');
		};
	}

	static function requireAction(actionPath:String) {
		js.Syntax.code("var requiredAction = require({0})", actionPath);
		return js.Syntax.code('new requiredAction.IdeckiaAction()');
	}
}
