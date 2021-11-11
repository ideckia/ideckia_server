package managers;

import exceptions.ItemNotFoundException;
import js.node.Require;
import tink.Json.parse as tinkJsonParse;
import tink.Json.stringify as tinkJsonStringify;
import websocket.WebSocketConnection;
import haxe.ds.Option;

using api.IdeckiaApi;
using api.internal.ServerApi;

class LayoutManager {
	@:v('ideckia.layout-file-path:layout.json')
	static var layoutFilePath:String;

	public static var layout:Layout;
	public static var currentDir:Dir;
	static var currentDirName:DirName;

	static inline var DEFAULT_TEXT_SIZE = 15;
	static inline var MAIN_DIR_ID = "_main_";

	public static function getLayoutPath() {
		return Ideckia.getAppPath() + '/' + layoutFilePath;
	}

	public static function readLayout() {
		var layoutFullPath = getLayoutPath();

		Log.info('Loading layout from [$layoutFullPath]');
		try {
			currentDirName = new DirName(MAIN_DIR_ID);
			layout = tinkJsonParse(sys.io.File.getContent(layoutFullPath));
		} catch (e:haxe.Exception) {
			Log.error(e);
			layout = {
				rows: 0,
				columns: 0,
				dirs: [],
				icons: []
			};
		}

		if (layout.textSize == null)
			layout.textSize = DEFAULT_TEXT_SIZE;
	}

	public static function load() {
		readLayout();
		addIds();
		changeDir(currentDirName);
		ActionManager.initClientActions();
	}

	public static function watchForChanges(connection:WebSocketConnection) {
		Chokidar.watch(getLayoutPath()).on('change', (_, _) -> {
			for (module in Require.cache)
				if (module != null && StringTools.endsWith(module.id, '.js'))
					Require.cache.remove(module.id);

			load();
			MsgManager.sendToAll(LayoutManager.currentDirForClient());
		});
	}

	public static function getCurrentItems() {
		return [for (i in currentDir.items) i];
	}

	public static function getAllItems() {
		return [
			for (f in layout.dirs)
				for (i in f.items)
					i
		];
	}

	public static function getItem(itemId:ItemId) {
		for (f in layout.dirs)
			for (i in f.items)
				if (i.id == itemId)
					return i;

		throw new ItemNotFoundException('Could not find [$itemId] item');
	}

	public static function getItemCurrentState(itemId:ItemId, advanceMultiState:Bool = false) {
		var item = getItem(itemId);

		var state:ServerState = switch item.kind {
			case null:
				{};
			case ChangeDir(_, state):
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

	public static inline function currentDirForClient():ServerMsg<ClientLayout> {
		Log.debug('Sending current directory to client.');

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

		var rows = currentDir.rows == null ? layout.rows : currentDir.rows;
		var columns = currentDir.columns == null ? layout.columns : currentDir.columns;

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

	public static function checkChangeDir(itemId:ItemId) {
		var item = getItem(itemId);

		return switch item.kind {
			case ChangeDir(toDir, _):
				Some(toDir);
			default:
				None;
		}
	}

	public static function isItemVisible(itemId:ItemId) {
		return getCurrentItems().filter(item -> item.id == itemId).length > 0;
	}

	public static function changeDir(dirName:DirName) {
		if (layout == null) {
			throw new haxe.Exception('There is no loaded layout. First call LayoutManager.load().');
		}

		Log.info('Switching dir to [$dirName]');
		var foundDirs = layout.dirs.filter(f -> f.name == dirName);
		var foundLength = foundDirs.length;
		if (foundLength == 0) {
			Log.error('Could not find dir with name [$dirName]');
			return;
		} else if (foundLength > 1) {
			Log.error('Found $foundLength dirs with name [$dirName]');
		}

		if (currentDir != null && dirName == currentDir.name) {
			return;
		}

		currentDir = foundDirs[0];
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

	public static function appendLayout(newLayout:Layout) {
		for (newDir in newLayout.dirs) {
			var setFolderRowColums = (newDir.rows == null || newDir == null)
				&& (newLayout.rows != layout.rows || newLayout.columns != layout.columns);

			if (setFolderRowColums) {
				newDir.rows = newLayout.rows;
				newDir.columns = newLayout.columns;
			}

			layout.dirs.push(newDir);
		}

		for (ic in newLayout.icons) {
			if (layout.icons.filter(li -> li.key == ic.key).length == 0)
				layout.icons.push(ic);
		}
	}

	public static function exportLayout(?_layout:Layout) {
		var expLayout = (_layout != null) ? Reflect.copy(_layout) : Reflect.copy(layout);
		// Remove item IDs
		setItemIds([
			for (f in expLayout.dirs)
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

	public static function exportDirs(dirNames:Array<String>):Option<{processedDirNames:Array<String>, layout:String}> {
		var foundDirs = layout.dirs.filter(d -> dirNames.indexOf(d.name.toString()) != -1);
		if (foundDirs.length == 0)
			return None;

		var dirIconNames = [];
		for (dir in foundDirs) {
			for (i in dir.items) {
				switch i.kind {
					case ChangeDir(_, state) if (state.icon != null && !dirIconNames.contains(state.icon)):
						dirIconNames.push(state.icon);
					case States(_, list):
						dirIconNames.concat(list.map(s -> s.icon).filter(i -> i != null && !dirIconNames.contains(i)));

					case _:
				}
			}
		}

		return Some({
			processedDirNames: foundDirs.map(f -> f.name.toString()),
			layout: tinkJsonStringify({
				rows: layout.rows,
				columns: layout.columns,
				dirs: foundDirs,
				icons: layout.icons.filter(ic -> dirIconNames.indexOf(ic.key) != -1)
			})
		});
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
