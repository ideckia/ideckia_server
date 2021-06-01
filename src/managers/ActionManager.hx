package managers;

import dialog.Dialog;

using api.IdeckiaApi;
using api.internal.ServerApi;

class ActionManager {
	@:v('ideckia.actions-path:actions')
	static var actionsPath:String;

	static var clientActions:Map<StateId, IdeckiaAction>;
	static var editorActions:Map<ActionId, IdeckiaAction>;

	static function loadAndInitAction(itemId:ItemId, state:ServerState):IdeckiaAction {
		var action = state.action;
		if (action == null)
			return null;

		try {
			var name = action.name;
			var actionPath = Ideckia.getAppPath() + '/${actionsPath}/$name';
			js.Syntax.code("var requiredAction = require({0})", actionPath);

			inline function createDialog(type:DialogType, text:String) {
				return new js.lib.Promise((resolve, reject) -> {
					var dialogType = switch type {
						case DialogType.error: Dialog.error;
						case DialogType.question: Dialog.question;
						case DialogType.entry: Dialog.entry;
						default: Dialog.info;
					}
					dialogType(text, name, 0, (code, returnValue, stdError) -> {
						if (code == 0)
							resolve(returnValue);
						else
							reject(stdError);
					});
				});
			}

			var idkServer:IdeckiaServer = {
				log: actionLog.bind(Log.debug, name),
				dialog: (type:DialogType, text:String) -> {
					new js.lib.Promise((resolve, reject) -> {
						var timeout = 0;
						var callback = (code, returnValue, stdError) -> {
							if (code == 0)
								resolve(returnValue);
							else
								reject(stdError);
						};
						switch type {
							case DialogType.error:
								Dialog.error(text, name, timeout, callback);
							case DialogType.question:
								Dialog.question(text, name, timeout, callback);
							case DialogType.entry:
								Dialog.entry(text, name, timeout, callback);
							default:
								Dialog.info(text, name, timeout, callback);
						}
					});
				},
				sendToClient: ClientManager.fromActionToClient.bind(itemId, name)
			};
			var ideckiaAction:IdeckiaAction = js.Syntax.code('new requiredAction.IdeckiaAction()');
			ideckiaAction.setProps(action.props, idkServer);
			ideckiaAction.init();

			return ideckiaAction;
		} catch (e:haxe.Exception) {
			Log.error('Error creating [${action.name}] action: ${e.message}');
		}

		return null;
	}

	public static function initClientActions() {
		clientActions = new Map();

		inline function getActionFromState(itemId:ItemId, state:ServerState) {
			Log.debug('item [$itemId] / state [id=${state.id}] [text=${state.text}], [icon=${state.icon}]');
			var action = loadAndInitAction(itemId, state);
			if (action != null)
				clientActions.set(state.id, action);
		}

		for (i in LayoutManager.getAllItems()) {
			switch i.kind {
				case SingleState(state):
					getActionFromState(i.id, state);
				case MultiState(_, states):
					for (s in states)
						getActionFromState(i.id, s);
				default:
			}
		}
	}

	static function actionLog(log:(data:Dynamic, ?posInfos:haxe.PosInfos) -> Void, actionName:String, v:Dynamic, ?posInfos:haxe.PosInfos) {
		log('[$actionName]: $v', posInfos);
	}

	public static function getEditorActionDescriptors() {
		if (editorActions == null) {
			editorActions = new Map();
			var cId = 0, action:IdeckiaAction;
			var actionPath = Ideckia.getAppPath() + '/${actionsPath}/';
			for (c in sys.FileSystem.readDirectory(actionPath)) {
				if (!sys.FileSystem.exists('$actionPath/$c/index.js'))
					continue;

				js.Syntax.code("var requiredAction = require({0})", '$actionPath/$c');
				action = js.Syntax.code('new requiredAction.IdeckiaAction()');
				editorActions.set(new ActionId(cId++), action);
			}
		}

		var descriptors:Array<ActionDescriptor> = [];
		var desc:ActionDescriptor;

		for (index => action in editorActions) {
			desc = action.getActionDescriptor();
			desc.id = index.toUInt();
			descriptors.push(desc);
		}

		var data:ServerMsg<Array<ActionDescriptor>> = {
			type: ServerMsgType.actionDescriptors,
			data: descriptors
		};

		return data;
	}

	public static function getActionByStateId(stateId:StateId) {
		if (clientActions == null || stateId == null)
			return null;

		return clientActions.get(stateId);
	}

	public static function testAction(state:ServerState) {
		var action = loadAndInitAction(new ItemId(-1), state);
		if (action != null)
			action.execute(state);
		else
			Log.error('the action is null');
	}
}
