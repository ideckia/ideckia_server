package managers;

import exceptions.ItemNotFoundException;

using api.IdeckiaCmdApi;
using Types;

import tink.Json.parse as tinkJsonParse;
import tink.Json.stringify as tinkJsonStringify;

class LayoutManager {
	@:v('ideckia.layout-file-path:layout.json')
	static var layoutFilePath:String;

	public static var layout:Layout;
	public static var currentFolder:Folder;
	static var currentFolderId:UInt = 0;

	public static function load() {
		var layoutFullPath = Sys.getCwd() + '/' + layoutFilePath;
		Log.debug('Loading layout from [$layoutFullPath]');
		try {
			layout = tinkJsonParse(sys.io.File.getContent(layoutFullPath));
		} catch (e:haxe.Exception) {
			Log.error(e);
			layout = {
				rows: 0,
				columns: 0,
				folders: [],
				icons: []
			};
		}
		addIds();
		switchFolder(currentFolderId);
		CmdManager.initClientCommands();
	}

	public static function getCurrentItems() {
		return [for (i in currentFolder.items) i];
	}

	public static function getAllItems() {
		return [
			for (f in layout.folders)
				for (i in f.items)
					i
		];
	}

	public static function getItem(itemId:UInt) {
		for (f in layout.folders)
			for (i in f.items)
				if (i.id == itemId)
					return i;

		throw new ItemNotFoundException('Could not find [$itemId]');
	}

	public static function getItemCurrentState(itemId:UInt, advanceMultiState:Bool = false) {
		Log.debug('Get state of item [$itemId]');
		var item = getItem(itemId);

		var state = switch item.kind {
			case SwitchFolder(_, state):
				state;
			case SingleState(state):
				state;
			case MultiState(index, states):
				if (advanceMultiState) {
					var newIndex = (index + 1) % states.length;
					item.kind = MultiState(newIndex, states);
				}
				states[index];
		}

		Log.debug('Items state: [$state]');
		return state;
	}

	public static inline function currentFolderForClient():ServerMsg<ClientLayout> {
		Log.debug('Sending current folder to client.');

		function getIconData(iconName:String) {
			if (layout.icons != null) {
				var f = layout.icons.filter(i -> i.key == iconName);
				if (f.length > 0)
					return f[0].value;
			}
			return null;
		}

		return {
			type: ServerMsgType.layout,
			data: {
				rows: layout.rows,
				columns: layout.columns,
				items: getCurrentItems().map(i -> {
					var currentState = getItemCurrentState(i.id);

					// from ServerState to ClientItem
					var clientItem:ClientItem = {id: i.id};

					if (currentState != null) {
						clientItem.text = currentState.text;
						clientItem.textColor = currentState.textColor;
						clientItem.icon = getIconData(currentState.icon);
						clientItem.bgColor = currentState.bgColor;
					}

					clientItem;
				})
			}
		};
	}

	public static function getSwitchFolderId(itemId:UInt) {
		var item = getItem(itemId);

		return switch item.kind {
			case SwitchFolder(toFolder, _):
				toFolder;
			default:
				-1;
		}
	}

	public static function switchFolder(folderId:UInt) {
		if (layout == null) {
			throw new haxe.Exception('There is no loaded layout. First call LayoutManager.load().');
		}

		Log.debug('Switching folder to [$folderId]');
		if (folderId >= layout.folders.length) {
			Log.error('Incorrect id for folder [$folderId]');
			return;
		}

		if (folderId == layout.folders.indexOf(currentFolder)) {
			return;
		}

		currentFolder = layout.folders[folderId];
		Log.debug('Folder switched');
	}

	static function addIds() {
		// folder IDs
		setIds(layout.folders);
		// item IDs
		setIds(getAllItems());
		// command IDs
		var cmds = [];
		for (i in getAllItems())
			switch i.kind {
				case SingleState(state):
					cmds.push(state.cmd);
				case MultiState(_, states):
					for (s in states)
						cmds.push(s.cmd);
				default:
			}
		setIds(cmds.filter(cmd -> cmd != null));
	}

	public static function exportLayout() {
		// Clone the current layout
		var expLayout:Layout = tinkJsonParse(tinkJsonStringify(layout));

		// Remove folder IDs
		setIds(expLayout.folders, true);

		// Remove item IDs
		setIds([
			for (f in expLayout.folders)
				for (i in f.items)
					i
		], true);

		// Remove cmd IDs
		var cmds = [];
		for (i in getAllItems())
			switch i.kind {
				case SingleState(state):
					cmds.push(state.cmd);
				case MultiState(_, states):
					for (s in states)
						cmds.push(s.cmd);
				default:
			}

		setIds(cmds.filter(cmd -> cmd != null), true);

		return tinkJsonStringify(expLayout);
	}

	static function setIds(elements:Array<{id:UInt}>, toNull:Bool = false) {
		var id = 0;
		for (e in elements)
			e.id = toNull ? null : id++;
	}
}
