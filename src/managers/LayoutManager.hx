package managers;

import exceptions.ItemNotFoundException;
import js.node.Require;
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
	static var currentFolderName:FolderName;

	static inline var DEFAULT_TEXT_SIZE = 15;
	static inline var MAIN_FOLDER_ID = "_main_";

	static function getLayoutPath() {
		return Ideckia.getAppPath() + '/' + layoutFilePath;
	}

	public static function readLayout() {
		var layoutFullPath = getLayoutPath();

		Log.info('Loading layout from [$layoutFullPath]');
		try {
			currentFolderName = new FolderName(MAIN_FOLDER_ID);
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

		if (layout.textSize == null)
			layout.textSize = DEFAULT_TEXT_SIZE;
	}

	public static function load() {
		readLayout();
		addIds();
		switchFolder(currentFolderName);
		ActionManager.initClientActions();
	}

	public static function watchForChanges(connection:WebSocketConnection) {
		Chokidar.watch(getLayoutPath()).on('change', (_, _) -> {
			for (module in Require.cache)
				if (module != null)
					Decache.run(module.id);

			load();
			MsgManager.sendToAll(LayoutManager.currentFolderForClient());
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
			case States(index, list):
				if (advanceMultiState) {
					var newIndex = (index + 1) % list.length;
					item.kind = States(newIndex, list);
				}
				list[index];
		}

		Log.debug('State of the item [id=$itemId]: [text=${state.text}], [icon=${state.icon}]');
		return state;
	}

	public static inline function currentFolderForClient():ServerMsg<ClientLayout> {
		Log.debug('Sending current folder to client.');

		function getIconData(iconName:String) {
			// Icon base64 directly in the state (from some action, for example)
			if (iconName != null && iconName.length > 1000)
				return iconName;
			if (layout.icons != null) {
				var f = layout.icons.filter(i -> i.key == iconName);
				if (f.length > 0)
					return f[0].value;
			}
			return null;
		}

		var rows = currentFolder.rows == null ? layout.rows : currentFolder.rows;
		var columns = currentFolder.columns == null ? layout.columns : currentFolder.columns;

		return {
			type: ServerMsgType.layout,
			data: {
				rows: rows,
				columns: columns,
				items: getCurrentItems().map(i -> {
					var currentState = getItemCurrentState(i.id);

					// from ServerState to ClientItem
					var clientItem:ClientItem = {id: i.id.toUInt()};

					if (currentState != null) {
						clientItem.text = currentState.text;
						clientItem.textSize = currentState.textSize == null ? layout.textSize : currentState.textSize;
						clientItem.textColor = currentState.textColor;
						clientItem.icon = getIconData(currentState.icon);
						clientItem.bgColor = currentState.bgColor;
					}

					clientItem;
				})
			}
		};
	}

	public static function getSwitchFolderName(itemId:ItemId) {
		var item = getItem(itemId);

		return switch item.kind {
			case SwitchFolder(toFolder, _):
				toFolder;
			default:
				null;
		}
	}

	public static function isItemVisible(itemId:ItemId) {
		return getCurrentItems().filter(item -> item.id == itemId).length > 0;
	}

	public static function switchFolder(folderName:FolderName) {
		if (layout == null) {
			throw new haxe.Exception('There is no loaded layout. First call LayoutManager.load().');
		}

		Log.info('Switching folder to [$folderName]');
		var foundFolders = layout.folders.filter(f -> f.name == folderName);
		var foundLength = foundFolders.length;
		if (foundLength == 0) {
			Log.error('Could not find folder with name [$folderName]');
			return;
		} else if (foundLength > 1) {
			Log.error('Found $foundLength folders with name [$folderName]');
		}

		if (currentFolder != null && folderName == currentFolder.name) {
			return;
		}

		currentFolder = foundFolders[0];
	}

	static function addIds() {
		// item IDs
		setItemIds(getAllItems());
		// action IDs
		var actions = [];
		for (i in getAllItems())
			i.kind = switch i.kind {
				case States(_, list):
					for (s in list)
						actions.concat(s.actions);
					States(0, list);
				case k:
					k;
			}
		setActionIds(actions.filter(action -> action != null));
	}

	public static function exportLayout() {
		// Clone the current layout
		var expLayout:Layout = tinkJsonParse(tinkJsonStringify(layout));

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
				case States(_, list):
					for (state in list)
						actions.concat(state.actions);
				default:
			}

		setActionIds(actions.filter(action -> action != null), true);

		return tinkJsonStringify(expLayout);
	}

	static function setItemIds(items:Array<ServerItem>, toNull:Bool = false) {
		var itemId = 0;
		var stateId = 0;
		for (i in items) {
			i.id = toNull ? null : new ItemId(itemId++);
			i.kind = switch i.kind {
				case States(_, list):
					for (state in list)
						state.id = toNull ? null : new StateId(stateId++);
					States(null, list);
				case k:
					k;
			}
		}
	}

	static function setActionIds(actions:Array<Action>, toNull:Bool = false) {
		var id = 0;
		for (a in actions)
			a.id = toNull ? null : new ActionId(id++);
	}
}
