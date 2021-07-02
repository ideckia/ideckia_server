package managers;

import js.node.Require;
import exceptions.ItemNotFoundException;
import tink.Json.parse as tinkJsonParse;
import tink.Json.stringify as tinkJsonStringify;
import websocket.WebSocketConnection;

using api.IdeckiaApi;
using api.internal.ServerApi;

class LayoutManager {
	@:v('ideckia.layout-file-path:layout.json')
	static var layoutFilePath:String;

	public static var layout:Layout;
	public static var currentFolder:Folder;
	static var currentFolderId:FolderId;

	static function getLayoutPath() {
		return Ideckia.getAppPath() + '/' + layoutFilePath;
	}

	public static function load() {
		var layoutFullPath = getLayoutPath();
		Log.info('Loading layout from [$layoutFullPath]');
		try {
			currentFolderId = new FolderId(0);
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
		ActionManager.initClientActions();
	}

	public static function watchForChanges(connection:WebSocketConnection) {
		Chokidar.watch(getLayoutPath()).on('change', (_, _) -> {
			for (module in Require.cache)
				Require.cache.remove(module.id);

			load();
			MsgManager.send(connection, LayoutManager.currentFolderForClient());
		});
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

	public static function getItem(itemId:ItemId) {
		for (f in layout.folders)
			for (i in f.items)
				if (i.id == itemId)
					return i;

		throw new ItemNotFoundException('Could not find [$itemId]');
	}

	public static function getItemCurrentState(itemId:ItemId, advanceMultiState:Bool = false) {
		var item = getItem(itemId);

		var state:ServerState = switch item.kind {
			case null:
				{};
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

		Log.debug('State of the item [id=$itemId]: [text=${state.text}], [icon=${state.icon}]');
		return state;
	}

	public static inline function currentFolderForClient():ServerMsg<ClientLayout> {
		Log.info('Sending current folder to client.');

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
					var clientItem:ClientItem = {id: i.id.toUInt()};

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

	public static function getSwitchFolderId(itemId:ItemId) {
		var item = getItem(itemId);

		return switch item.kind {
			case SwitchFolder(toFolder, _):
				toFolder;
			default:
				null;
		}
	}

	public static function switchFolder(folderId:FolderId) {
		if (layout == null) {
			throw new haxe.Exception('There is no loaded layout. First call LayoutManager.load().');
		}

		Log.info('Switching folder to [$folderId]');
		var folderUInt = folderId.toUInt();
		if (folderUInt >= layout.folders.length) {
			Log.error('Incorrect id for folder [$folderId]');
			return;
		}

		if (folderUInt == layout.folders.indexOf(currentFolder)) {
			return;
		}

		currentFolder = layout.folders[folderUInt];
		Log.info('Folder switched');
	}

	static function addIds() {
		// folder IDs
		setFolderIds(layout.folders);
		// item IDs
		setItemIds(getAllItems());
		// action IDs
		var actions = [];
		for (i in getAllItems())
			switch i.kind {
				case SingleState(state):
					actions.push(state.action);
				case MultiState(_, states):
					for (s in states)
						actions.push(s.action);
				default:
			}
		setActionIds(actions.filter(action -> action != null));
	}

	public static function exportLayout() {
		// Clone the current layout
		var expLayout:Layout = tinkJsonParse(tinkJsonStringify(layout));

		// Remove folder IDs
		setFolderIds(expLayout.folders, true);

		// Remove item IDs
		setItemIds([
			for (f in expLayout.folders)
				for (i in f.items)
					i
		], true);

		// Remove action IDs
		var actions = [];
		for (i in getAllItems())
			switch i.kind {
				case SingleState(state):
					actions.push(state.action);
				case MultiState(_, states):
					for (s in states)
						actions.push(s.action);
				default:
			}

		setActionIds(actions.filter(action -> action != null), true);

		return tinkJsonStringify(expLayout);
	}

	static function setFolderIds(folders:Array<Folder>, toNull:Bool = false) {
		var id = 0;
		for (f in folders)
			f.id = toNull ? null : new FolderId(id++);
	}

	static function setItemIds(items:Array<ServerItem>, toNull:Bool = false) {
		var itemId = 0;
		var stateId = 0;
		for (i in items) {
			i.id = toNull ? null : new ItemId(itemId++);
			switch i.kind {
				case SingleState(state):
					state.id = toNull ? null : new StateId(stateId++);
				case MultiState(_, states):
					for (s in states)
						s.id = toNull ? null : new StateId(stateId++);
				default:
			}
		}
	}

	static function setActionIds(actions:Array<Action>, toNull:Bool = false) {
		var id = 0;
		for (a in actions)
			a.id = toNull ? null : new ActionId(id++);
	}
}
