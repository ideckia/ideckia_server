package managers;

import haxe.ds.Option;

using api.IdeckiaApi;
using api.internal.ServerApi;

class ActionManager {
	@:v('ideckia.actions-path:actions')
	static var actionsPath:String;

	static var clientActions:Map<StateId, Array<IdeckiaAction>>;

	static var actionDescriptors:Array<ActionDescriptor>;

	static function loadAndInitAction(itemId:ItemId, state:ServerState):Option<Array<IdeckiaAction>> {
		var actions = state.actions;
		if (actions == null || actions.length == 0)
			return None;

		var retActions = [];
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
					updateClientState: ClientManager.fromActionToClient.bind(itemId, name)
				};
				if (!action.enabled) {
					continue;
				}
				var actionPath = Ideckia.getAppPath() + '/${actionsPath}/$name';
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
					Log.error('Error initializing [${name}] action of the state [id=${state.id}]: $error');
				});

				retActions.push(ideckiaAction);
			} catch (e:haxe.Exception) {
				Log.error('Error creating [${action.name}] action: ${e.message}');
			}
		}
		return Some(retActions);
	}

	public static function initClientActions() {
		clientActions = new Map();
		actionDescriptors = null;

		inline function getActionFromState(itemId:ItemId, state:ServerState) {
			Log.debug('item [$itemId] / state [id=${state.id}] [text=${state.text}], [icon=${state.icon}]');
			switch loadAndInitAction(itemId, state) {
				case Some(actions):
					clientActions.set(state.id, actions);
				case None:
			};
		}

		for (i in LayoutManager.getAllItems()) {
			switch i.kind {
				case States(_, list):
					for (state in list)
						getActionFromState(i.id, state);
				default:
			}
		}
	}

	static function actionLog(log:(data:Dynamic, ?posInfos:haxe.PosInfos) -> Void, actionName:String, v:Dynamic, ?posInfos:haxe.PosInfos) {
		log('[$actionName]: $v', posInfos);
	}

	public static function getEditorActionDescriptors() {
		var actionPath = Ideckia.getAppPath() + '/${actionsPath}/';
		if (actionDescriptors == null) {
			actionDescriptors = [];
			var desc:ActionDescriptor;
			var cId = 0, action:IdeckiaAction;
			for (c in sys.FileSystem.readDirectory(actionPath)) {
				if (!sys.FileSystem.exists('$actionPath/$c/index.js'))
					continue;

				action = requireAction('$actionPath/$c');
				try {
					desc = action.getActionDescriptor();
					desc.id = cId++;
					actionDescriptors.push(desc);
				} catch (e:haxe.Exception) {
					Log.error('Error reading action descriptor of $c: $e');
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
		switch loadAndInitAction(new ItemId(-1), state) {
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
