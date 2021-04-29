package managers;

using api.IdeckiaApi;
using Types;

class ActionManager {
	@:v('ideckia.actions-path:actions')
	static var actionsPath:String;

	static var clientActions:Map<Int, IdeckiaAction>;
	static var editorActions:Map<Int, IdeckiaAction>;

	public static function initClientActions() {
		clientActions = new Map();

		function fromState(itemId:UInt, state:ServerState) {
			var stateAction = state.action;
			if (stateAction == null)
				return;

			var name = stateAction.name;
			try {
				var props = stateAction.props;
				var actionPath = Sys.getCwd() + '/${actionsPath}/$name';
				js.Syntax.code("var requiredAction = require({0})", actionPath);

				var idkServer:IdeckiaServer = {
					log: {
						debug: actionLog.bind(Log.debug, name),
						info: actionLog.bind(Log.info, name),
						warn: actionLog.bind(Log.warn, name),
						error: actionLog.bind(Log.error, name)
					},
					sendToClient: ClientManager.fromActionToClient.bind(itemId),
					props: (key:String) -> appropos.Appropos.get(key, '')
				};
				var action:IdeckiaAction = js.Syntax.code('new requiredAction.IdeckiaAction()');
				action.setProps(props, state, idkServer);
				action.init();

				clientActions.set(stateAction.id, action);
			} catch (e:haxe.Exception) {
				Log.error('Error creating [$name] action: ${e.message}');
			}
		}

		for (i in LayoutManager.getAllItems()) {
			switch i.kind {
				case SingleState(state):
					fromState(i.id, state);
				case MultiState(_, states):
					for (s in states)
						fromState(i.id, s);
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
				editorActions.set(cId++, action);
			}
		}

		var descriptors:Array<ActionDescriptor> = [];
		var desc:ActionDescriptor;

		for (index => action in editorActions) {
			desc = action.getActionDescriptor();
			desc.id = index;
			descriptors.push(desc);
		}

		var data:ServerMsg<Array<ActionDescriptor>> = {
			type: ServerMsgType.actionDescriptors,
			data: descriptors
		};

		return data;
	}

	public static function getClientAction(id:UInt) {
		if (clientActions == null)
			return null;

		for (cid => action in clientActions)
			if (cid == id)
				return action;

		return null;
	}
}
