package managers;

import exceptions.ItemNotFoundException;
import haxe.ds.Option;
import js.node.Require;
import tink.Json.parse as tinkJsonParse;
import tink.Json.stringify as tinkJsonStringify;

using api.IdeckiaApi;
using api.internal.ServerApi;

class LayoutManager {
	@:v('ideckia.layout-file-path:layout.json')
	static var layoutFilePath:String;

	public static var layout:Layout;
	public static var currentDir:Dir;
	static var currentDirName:DirName = new DirName(MAIN_DIR_ID);
	static var isWatching:Bool = false;

	static inline var DEFAULT_TEXT_SIZE = 15;
	static inline var MAIN_DIR_ID = "_main_";

	public static function getLayoutPath() {
		return Ideckia.getAppPath() + '/' + layoutFilePath;
	}

	public static function readLayout() {
		var layoutFullPath = getLayoutPath();

		Log.info('Loading layout from [$layoutFullPath]');
		try {
			layout = tinkJsonParse(sys.io.File.getContent(layoutFullPath));
		} catch (e:haxe.Exception) {
			Log.error(e);
			layout = {
				rows: 0,
				columns: 0,
				dirs: [],
				fixedItems: [],
				sharedVars: [],
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

	public static function watchForChanges() {
		if (isWatching)
			return;

		Chokidar.watch(getLayoutPath()).on('change', (_, _) -> {
			for (module in Require.cache)
				if (module != null && StringTools.endsWith(module.id, '.js'))
					Require.cache.remove(module.id);

			Log.info('Layout file changed, reloading...');
			load();
			MsgManager.sendToAll(LayoutManager.currentDirForClient());
		});

		isWatching = true;
	}

	public static function getCurrentItems() {
		return [for (i in currentDir.items) i];
	}

	public static function getAllItems(?fromLayout:Layout) {
		if (fromLayout == null)
			fromLayout = layout;

		var fixedItems = fromLayout.fixedItems == null ? [] : fromLayout.fixedItems;
		return [
			for (f in fromLayout.dirs)
				for (i in f.items)
					i
		].concat([
			for (fi in fixedItems)
				fi
		]);
	}

	public static function getItem(itemId:ItemId) {
		for (i in getAllItems())
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

		Log.debug('State [id=${state.id}] of the item [id=$itemId]: [text=${state.text}], [icon=${state.icon}]');
		return state;
	}

	public static function getSharedValue(sharedName:String) {
		if (layout.sharedVars != null) {
			for (sv in layout.sharedVars) {
				if (sv.key == sharedName)
					return Some(sv.value);
			}
		}

		return None;
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

		function transformItem(item:ServerItem) {
			var currentState = getItemCurrentState(item.id);

			// from ServerState to ClientItem
			var clientItem:ClientItem = {id: item.id.toUInt()};

			if (currentState != null) {
				clientItem.text = currentState.text;
				clientItem.textSize = currentState.textSize == null ? layout.textSize : currentState.textSize;
				clientItem.textColor = currentState.textColor;
				clientItem.textPosition = currentState.textPosition;
				clientItem.icon = getIconData(currentState.icon);
				clientItem.bgColor = currentState.bgColor;
			}

			return clientItem;
		}

		return {
			type: ServerMsgType.layout,
			data: {
				rows: rows,
				columns: columns,
				items: getCurrentItems().map(transformItem),
				fixedItems: layout.fixedItems == null ? [] : layout.fixedItems.map(transformItem)
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
			throw new haxe.Exception('There is no loaded layout. Call LayoutManager.load() first.');
		}

		Log.info('Switching dir to [$dirName]');
		var foundDirs = layout.dirs.filter(f -> f.name == dirName);
		var foundLength = foundDirs.length;
		if (foundLength == 0) {
			Log.error('Could not find dir with name [$dirName]');
			Ideckia.dialog.error('Error switching directory', 'Could not find dir with name [$dirName]');
			return;
		} else if (foundLength > 1) {
			Log.error('Found $foundLength dirs with name [$dirName]');
		}

		if (currentDir != null && dirName == currentDir.name) {
			return;
		}

		currentDir = foundDirs[0];
		currentDirName = currentDir.name;
	}

	static function addIds() {
		// item IDs
		setItemAndStateIds(getAllItems());
		// action IDs
		setActionIds(getAllItems());
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

	public static function exportLayout(?fromLayout:Layout) {
		var expLayout = (fromLayout != null) ? Reflect.copy(fromLayout) : Reflect.copy(layout);

		var expItems = getAllItems(expLayout);

		setItemAndStateIds(expItems, true);
		setActionIds(expItems, true);

		return tinkJsonStringify(expLayout);
	}

	public static function exportDirs(dirNames:Array<String>):Option<{processedDirNames:Array<String>, layout:String}> {
		var expLayout = Reflect.copy(layout);
		var foundDirs = expLayout.dirs.filter(d -> dirNames.indexOf(d.name.toString()) != -1);
		if (foundDirs.length == 0)
			return None;

		var dirIconNames = [];
		var expItems = [];
		for (dir in foundDirs) {
			for (i in dir.items) {
				expItems.push(i);
				switch i.kind {
					case ChangeDir(_, state) if (state.icon != null && !dirIconNames.contains(state.icon)):
						dirIconNames.push(state.icon);
					case States(_, list):
						dirIconNames = dirIconNames.concat(list.map(s -> s.icon).filter(i -> i != null && !dirIconNames.contains(i)));
					case _:
				}
			}
		}

		setItemAndStateIds(expItems, true);
		setActionIds(expItems, true);

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

	static function setItemAndStateIds(items:Array<ServerItem>, toNull:Bool = false) {
		var itemId = 0;
		var stateId = 0;
		for (i in items) {
			i.id = toNull ? null : new ItemId(itemId++);
			i.kind = switch i.kind {
				case States(_, list):
					for (state in list)
						state.id = toNull ? null : new StateId(stateId++);
					States(null, list);
				case ChangeDir(toDir, state):
					state.id = toNull ? null : new StateId(stateId++);
					ChangeDir(toDir, state);
				case k:
					k;
			}
		}
	}

	static function setActionIds(items:Array<ServerItem>, toNull:Bool = false) {
		var id = 0;
		for (i in items)
			i.kind = switch i.kind {
				case States(_, list):
					for (s in list) {
						if (s.actions != null)
							for (a in s.actions)
								if (a != null)
									a.id = toNull ? null : new ActionId(id++);
					}
					States(0, list);
				case k:
					k;
			}
	}
}
