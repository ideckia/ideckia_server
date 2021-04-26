package managers;

using api.IdeckiaCmdApi;
using Types;

class CmdManager {
	@:v('ideckia.commands-path:commands')
	static var commandsPath:String;

	static var clientCommands:Map<Int, IdeckiaCmd>;
	static var editorCommands:Map<Int, IdeckiaCmd>;

	public static function initClientCommands() {
		clientCommands = new Map();

		function fromState(itemId:UInt, state:ServerState) {
			var cmd = state.cmd;
			if (cmd == null)
				return;

			var name = cmd.name;
			try {
				var props = cmd.props;
				var commandPath = Sys.getCwd() + '/${commandsPath}/$name';
				js.Syntax.code("var requiredCmd = require({0})", commandPath);

				var idkServer:IdeckiaServer = {
					log: {
						debug: cmdLog.bind(Log.debug, name),
						info: cmdLog.bind(Log.info, name),
						warn: cmdLog.bind(Log.warn, name),
						error: cmdLog.bind(Log.error, name)
					},
					sendToClient: ClientManager.fromCmdToClient.bind(itemId),
					props: (key:String) -> appropos.Appropos.get(key, '')
				};
				var command:IdeckiaCmd = js.Syntax.code('new requiredCmd.IdeckiaCmd()');
				command.setProps(props, state, idkServer);
				command.init();

				clientCommands.set(cmd.id, command);
			} catch (e:haxe.Exception) {
				Log.error('Error creating [$name] command: ${e.message}');
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

	static function cmdLog(log:(data:Dynamic, ?posInfos:haxe.PosInfos) -> Void, cmdName:String, v:Dynamic, ?posInfos:haxe.PosInfos) {
		log('[$cmdName]: $v', posInfos);
	}

	public static function getEditorCmdDescriptors() {
		if (editorCommands == null) {
			editorCommands = new Map();
			var cId = 0, command:IdeckiaCmd;
			var commandPath = Sys.getCwd() + '/${commandsPath}/';
			for (c in sys.FileSystem.readDirectory(commandPath)) {
				if (!sys.FileSystem.exists('$commandPath/$c/index.js'))
					continue;

				js.Syntax.code("var requiredCmd = require({0})", '$commandPath/$c');
				command = js.Syntax.code('new requiredCmd.IdeckiaCmd()');
				editorCommands.set(cId++, command);
			}
		}

		var descriptors:Array<CmdDescriptor> = [];
		var desc:CmdDescriptor;

		for (index => cmd in editorCommands) {
			desc = cmd.getCmdDescriptor();
			desc.id = index;
			descriptors.push(desc);
		}

		var data:ServerMsg<Array<CmdDescriptor>> = {
			type: ServerMsgType.commandDescriptors,
			data: descriptors
		};

		return data;
	}

	public static function getClientCommand(id:UInt) {
		if (clientCommands == null)
			return null;

		for (cid => cmd in clientCommands)
			if (cid == id)
				return cmd;

		return null;
	}
}
