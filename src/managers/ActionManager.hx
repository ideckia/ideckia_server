package managers;

import haxe.ds.Option;
import dialog.Dialog;

using api.IdeckiaApi;
using api.internal.ServerApi;

class ActionManager {
	@:v('ideckia.actions-path:actions')
	static var actionsPath:String;

	static var clientActions:Map<StateId, Array<IdeckiaAction>>;
	static var editorActions:Map<ActionId, IdeckiaAction>;

	static function loadAndInitAction(itemId:ItemId, state:ServerState):Option<Array<IdeckiaAction>> {
		var actions = state.actions;
		if (actions == null || actions.length == 0)
			return None;

		var retActions = [];
		for (action in actions) {
			try {
				var name = action.name;
				var actionPath = Ideckia.getAppPath() + '/${actionsPath}/$name';
				js.Syntax.code("var requiredAction = require({0})", actionPath);

				var idkServer:IdeckiaServer = {
					log: actionLog.bind(Log.debug, name),
					dialog: (type:DialogType, text:String) -> Dialog.show(type, name, text),
					sendToClient: ClientManager.fromActionToClient.bind(itemId, name)
				};
				var ideckiaAction:IdeckiaAction = js.Syntax.code('new requiredAction.IdeckiaAction()');
				ideckiaAction.setup(action.props, idkServer);
				ideckiaAction.init(state);

				retActions.push(ideckiaAction);
			} catch (e:haxe.Exception) {
				Log.error('Error creating [${action.name}] action: ${e.message}');
			}
		}

		return Some(retActions);
	}

	public static function initClientActions() {
		clientActions = new Map();

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

		return descriptors;
	}

	public static function getActionByStateId(stateId:StateId) {
		if (clientActions == null || stateId == null)
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
}
