package managers;

import api.action.creator.ActionCreator;
import haxe.ds.Option;
import js.node.Require;

using api.IdeckiaApi;
using api.internal.ServerApi;
using StringTools;

class ActionManager {
	@:v('ideckia.actions-path:actions')
	static var actionsPath:String;
	@:v('ideckia.actions-load-timeout-ms:1000')
	static var actionsLoadTimeoutMs:UInt;

	static var clientActions:Map<StateId, Array<{id:ActionId, action:IdeckiaAction}>>;
	static var actionDescriptors:Array<ActionDescriptor>;
	static var isWatching:Bool = false;
	public static var creatingNewAction:Bool = false;

	public static function getActionsPath() {
		if (js.node.Path.isAbsolute(actionsPath))
			return actionsPath;
		return Ideckia.getAppPath(actionsPath);
	}

	public static function loadAndInitAction(itemId:ItemId, state:ServerState, addToCache:Bool = true):js.lib.Promise<Bool> {
		return new js.lib.Promise<Bool>((resolve, reject) -> {
			Log.debug('Load actions from item [$itemId] / state [id=${state.id}] [text=${state.text}], [icon=${(state.icon == null) ? null : state.icon.substring(0, 50) + "..."}]');
			var actions = state.actions;
			if (actions == null || actions.length == 0) {
				reject('No actions found');
				return;
			}

			var retActions = [];
			var initPromises = [];
			var actionsBasePath = getActionsPath();
			for (action in actions) {
				Log.debug('    Loading action [id=${action.id}] [name=${action.name}]');
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
					initPromises.push(ideckiaAction.init(state));

					retActions.push({id: action.id, action: ideckiaAction});
				} catch (e:haxe.Exception) {
					Log.error('Error creating [${action.name}] action: ${e.message}');
					Log.raw(e.stack);
				}
			}

			var allSettled = false;
			var promisesTimeoutResolved = false;
			js.lib.Promise.allSettled(initPromises).then(statusPromiseResponses -> {
				if (promisesTimeoutResolved)
					return;

				allSettled = true;
				for (i => response in statusPromiseResponses) {
					switch response.status {
						case Fulfilled:
							var newState = response.value;
							if (newState != null) {
								state.text = newState.text;
								state.textColor = newState.textColor;
								state.textSize = newState.textSize;
								state.icon = newState.icon;
								state.bgColor = newState.bgColor;
							}
						case Rejected:
							Log.error('Error initializing action of the state [id=${state.id}]: [${response.reason}]');
					}
				}

				resolve(true);
			});

			if (addToCache)
				clientActions.set(state.id, retActions);

			haxe.Timer.delay(() -> {
				promisesTimeoutResolved = true;
				if (!allSettled) {
					var msg = 'Not all init promises settled for state [${state.id}]';
					Log.error(msg);
					reject(msg);
				}
			}, actionsLoadTimeoutMs);
		});
	}

	public static function initClientActions():js.lib.Promise<Bool> {
		return new js.lib.Promise((resolve, reject) -> {
			clientActions = new Map();
			actionDescriptors = null;

			var promises = [];
			for (i in LayoutManager.getAllItems()) {
				switch i.kind {
					case States(_, list):
						for (state in list)
							promises.push(loadAndInitAction(i.id, state));
					default:
				}
			}

			js.lib.Promise.allSettled(promises).then(_ -> resolve(true));
		});
	}

	public static function unloadActions() {
		LayoutManager.hideCurrentItems();
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
			if (creatingNewAction)
				return;
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
		return new js.lib.Promise((resolve, reject) -> {
			var actionPath = getActionsPath();
			actionDescriptors = [];
			var cId = 0,
				action:IdeckiaAction,
				presetsPath,
				descriptorPromises = [];
			for (c in sys.FileSystem.readDirectory(actionPath)) {
				if (!sys.FileSystem.exists('$actionPath/$c/index.js') || c.startsWith('_'))
					continue;

				action = requireAction('$actionPath/$c');
				try {
					descriptorPromises.push(action.getActionDescriptor());
				} catch (e:haxe.Exception) {
					Ideckia.dialog.error('No description found', 'Error reading descriptor of the action [$c].');
					Log.error('Error reading descriptor of the action [$c]: ${e.message}');
					Log.raw(e.stack);
				}
			}

			var allSettled = false;
			var promisesTimeoutResolved = false;
			js.lib.Promise.allSettled(descriptorPromises).then(descriptorPromiseResponses -> {
				if (promisesTimeoutResolved)
					return;

				allSettled = true;
				var descriptor:ActionDescriptor;
				for (descResponse in descriptorPromiseResponses) {
					switch descResponse.status {
						case Fulfilled:
							descriptor = descResponse.value;
							presetsPath = '$actionPath/${descriptor.name}/presets.json';
							descriptor.presets = (sys.FileSystem.exists(presetsPath)) ? haxe.Json.parse(sys.io.File.getContent(presetsPath)) : [];
							descriptor.id = cId++;
							actionDescriptors.push(descriptor);
						case Rejected:
							Log.error('Error getting descriptor of an action]: [${descResponse.reason}]');
					}
				}

				resolve(actionDescriptors);
			});
		});
	}

	public static function getActionsByStateId(stateId:StateId) {
		if (clientActions == null || stateId == null || !clientActions.exists(stateId))
			return None;
		var actions = [
			for (cAction in clientActions.get(stateId))
				cAction.action
		];
		return Some(actions);
	}

	public static function getActionsStatusesByStateId(stateId:StateId) {
		return new js.lib.Promise((resolve, reject) -> {
			var statuses:Map<UInt, ActionStatus> = [];
			if (clientActions == null || stateId == null || !clientActions.exists(stateId)) {
				resolve(statuses);
				return;
			}
			var stateActions = clientActions.get(stateId);
			var promises = [];
			var hasGetStatusMethod;
			for (cAction in stateActions) {
				hasGetStatusMethod = js.Syntax.code("typeof {0}.getStatus", cAction.action) == 'function';
				if (!hasGetStatusMethod)
					promises.push(js.lib.Promise.reject('No [getStatus] method found'));
				else
					promises.push(cAction.action.getStatus());
			}

			var allSettled = false;
			var promisesTimeoutResolved = false;
			js.lib.Promise.allSettled(promises).then(statusPromiseResponses -> {
				if (promisesTimeoutResolved)
					return;

				var statusResponse;
				allSettled = true;
				for (i => cAction in stateActions) {
					statusResponse = statusPromiseResponses[i];
					switch statusResponse.status {
						case Fulfilled:
							statuses.set(cAction.id.toUInt(), statusResponse.value);
						case Rejected:
							statuses.set(cAction.id.toUInt(), {code: ActionStatusCode.unknown});
							Log.error('Error getting Status of action [id=${cAction.id}] in the state [id=${stateId}]: [${statusResponse.reason}]');
					}
				}

				resolve(statuses);
			});

			haxe.Timer.delay(() -> {
				promisesTimeoutResolved = true;
				if (!allSettled) {
					Log.error('Not all IdeckiaAction.getStatus promises settled for state [${stateId}]');
					for (i => cAction in stateActions) {
						if (!statuses.exists(cAction.id.toUInt())) {
							Log.debug('setting ${cAction.id}');
							statuses.set(cAction.id.toUInt(), {code: ActionStatusCode.unknown});
						}
					}
					resolve(statuses);
				}
			}, actionsLoadTimeoutMs);
		});
	}

	public static function getActionDescriptorById(actionId:ActionId) {
		if (clientActions == null || actionId == null)
			return js.lib.Promise.reject('No client actions loaded yet');

		for (cActions in clientActions)
			for (cAction in cActions)
				if (cAction.id == actionId)
					return cAction.action.getActionDescriptor();

		return js.lib.Promise.reject('No descriptor found for action [id=${actionId.toUInt()}]');
	}

	public static function getActionTemplates() {
		var tplDirectory = haxe.io.Path.join([actionsPath, 'tpl']);

		var templates:Array<TemplateDef> = [for (tpl in ActionCreator.TEMPLATES_LIST) {tplName: tpl, tplDirectory: 'embed'}];
		if (sys.FileSystem.exists(tplDirectory))
			for (tpl in sys.FileSystem.readDirectory(tplDirectory))
				if (sys.FileSystem.isDirectory(tplDirectory + '/$tpl')) {
					var macroTplIndex = ActionCreator.TEMPLATES_LIST.indexOf(tpl);
					if (macroTplIndex != -1) {
						templates.splice(macroTplIndex, 1);
					}
					templates.push({tplName: tpl, tplDirectory: tplDirectory});
				}
		return templates;
	}

	static function requireAction(actionPath:String) {
		js.Syntax.code("var requiredAction = require({0})", actionPath);
		return js.Syntax.code('new requiredAction.IdeckiaAction()');
	}
}
