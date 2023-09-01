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
			var promiseResolved = false;
			js.lib.Promise.allSettled(initPromises).then(initPromisesResponse -> {
				if (promiseResolved)
					return;

				allSettled = true;
				for (i => response in initPromisesResponse) {
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
							Log.error('Error initializing action of the state [id=${state.id}]');
							Log.raw(response.reason.stack);
					}
				}

				resolve(true);
			});

			if (addToCache)
				clientActions.set(state.id, retActions);

			haxe.Timer.delay(() -> {
				promiseResolved = true;
				if (!allSettled)
					reject('Not all promised settled for state [${state.id}]');
			}, 1000);
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

	public static function getActionsByStateId(stateId:StateId) {
		if (clientActions == null || stateId == null || !clientActions.exists(stateId))
			return None;
		var actions = [
			for (cAction in clientActions.get(stateId))
				cAction.action
		];
		return Some(actions);
	}

	public static function getActionDescriptorById(actionId:ActionId) {
		if (clientActions == null || actionId == null)
			return None;

		for (cActions in clientActions) {
			for (cAction in cActions) {
				if (cAction.id == actionId)
					return Some(cAction.action.getActionDescriptor());
			}
		}

		return None;
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
