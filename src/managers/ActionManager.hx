package managers;

using api.IdeckiaApi;
using Types;

class ActionManager {
	@:v('ideckia.actions-path:actions')
	static var actionsPath:String;

	static var clientActions:Map<ItemId, IdeckiaAction>;
	static var editorActions:Map<ActionId, IdeckiaAction>;

	static function loadAndInitAction(itemId:ItemId, state:ServerState):IdeckiaAction {
		var action = state.action;
		if (action == null)
			return null;

		try {
			var name = action.name;
			var actionPath = Sys.getCwd() + '/${actionsPath}/$name';
			js.Syntax.code("var requiredAction = require({0})", actionPath);

			var idkServer:IdeckiaServer = {
				log: {
					debug: actionLog.bind(Log.debug, name),
					info: actionLog.bind(Log.info, name),
					warn: actionLog.bind(Log.warn, name),
					error: actionLog.bind(Log.error, name)
				},
				sendToClient: ClientManager.fromActionToClient.bind(itemId)
			};
			var ideckiaAction:IdeckiaAction = js.Syntax.code('new requiredAction.IdeckiaAction()');
			ideckiaAction.setProps(action.props, state, idkServer);
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
			Log.debug('item [$itemId] / state [text=${state.text}], [icon=${state.icon}]');
			var action = loadAndInitAction(itemId, state);
			if (action != null)
				clientActions.set(itemId, action);
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
			var actionPath = Sys.getCwd() + '/${actionsPath}/';
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

	public static function getClientAction(id:ItemId) {
		if (clientActions == null)
			return null;

		for (cid => action in clientActions)
			if (cid == id)
				return action;

		return null;
	}

	public static function testAction(state:ServerState) {
		var action = loadAndInitAction(new ItemId(-1), state);
		if (action != null)
			action.execute();
		else
			Log.error('the action is null');
	}
}
