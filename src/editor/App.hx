package;

import js.html.InputElement;
import api.internal.ServerApi;
import js.html.MouseEvent;
import js.html.SelectElement;

using api.IdeckiaApi;
using hx.Selectors;

typedef IconData = {
	var name:String;
	var base64:String;
}

class App {
	static var websocket:js.html.WebSocket;

	public static var editorData:EditorData;
	public static var icons:Array<IconData>;

	function new() {
		js.Browser.window.onload = onLoad;
	}

	function onLoad() {
		initWebsocketServer();

		Id.add_dir_btn.get().addEventListener('click', (_) -> {
			var dirName = js.Browser.window.prompt('Tell me the name of the new directory');

			if (dirName == null)
				return;

			var dirs = editorData.layout.dirs;
			dirs.push({
				name: new DirName(dirName),
				items: []
			});

			updateDirsSelect();
		});

		Id.add_item_btn.get().addEventListener('click', (_) -> {
			switch Utils.createNewItem() {
				case Some(item):
					@:privateAccess DirEdit.currentDir.items.push(item);
					DirEdit.refresh();
				case None:
			}
		});

		Id.delete_dir_btn.get().addEventListener('click', (_) -> {
			var currentDir = @:privateAccess DirEdit.currentDir;
			if (js.Browser.window.confirm('Are you sure you want to delete the [${currentDir.name.toString()}] directory?')) {
				var dirs = editorData.layout.dirs;
				dirs.remove(currentDir);
				updateDirsSelect();
			}
		});

		Id.add_icon_btn.get().addEventListener('click', (_) -> {
			var iconName = js.Browser.window.prompt('New icon name');

			if (iconName == null)
				return;

			if (icons.filter(i -> i.name == iconName).length > 0) {
				js.Browser.alert('Already exists $iconName icon in the current list. Select another name, please.');
				return;
			}

			var iconData = js.Browser.window.prompt('The icon encoded in base64, please');

			if (iconData == null)
				return;

			editorData.layout.icons.push({
				key: iconName,
				value: iconData
			});

			updateIcons();
		});

		Id.save_btn.get().addEventListener('click', (_) -> {
			var msg:EditorMsg = {
				type: EditorMsgType.saveLayout,
				whoami: editor,
				layout: editorData.layout
			};
			websocket.send(tink.Json.stringify(msg));
		});
	}

	static function updateDirsSelect(?currentDirIndex:Int) {
		var dirs = editorData.layout.dirs;
		for (selElement in Cls.dir_select.get()) {
			Utils.fillSelectElement(cast(selElement, SelectElement), [for (i in 0...dirs.length) {value: i, text: dirs[i].name.toString()}]);
		}

		if (dirs.length > 0) {
			Id.layout_container.get().classList.remove(Cls.hidden);
			Id.delete_dir_btn.get().classList.remove(Cls.hidden);
			if (currentDirIndex == null)
				DirEdit.show(dirs[0]);
			else
				DirEdit.show(dirs[dirs.length - 1]);
		} else {
			Id.layout_container.get().classList.add(Cls.hidden);
			Id.delete_dir_btn.get().classList.add(Cls.hidden);
		}
	}

	static function updateIcons() {
		icons = [
			for (i in App.editorData.layout.icons)
				{
					name: i.key,
					base64: i.value
				}
		];
		icons.insert(0, {name: '', base64: ''});
	}

	static function initWebsocketServer() {
		final port = js.Browser.location.port;
		websocket = new js.html.WebSocket('ws://127.0.0.1:${port}');

		websocket.onopen = () -> {
			var msg:EditorMsg = {
				type: EditorMsgType.getEditorData,
				whoami: editor
			};
			websocket.send(haxe.Json.stringify(msg));
		}

		websocket.onmessage = (event:{data:Any}) -> {
			var serverData:ServerMsg<Any> = haxe.Json.parse(event.data);
			switch serverData.type {
				case ServerMsgType.editorData:
					editorData = serverData.data;

					updateIcons();

					var dirs = editorData.layout.dirs;
					Id.dir_select.get().addEventListener('change', (event) -> {
						var selectedIndex = Std.parseInt(Id.dir_select.as(SelectElement).value);
						DirEdit.show(dirs[selectedIndex]);
					});

					updateDirsSelect();

				case _:
					trace('Unhandled message from server [${haxe.Json.stringify(event)}]');
			};
		}

		websocket.onerror = (event) -> {
			var msg = 'WebSocket connection to "${event.target.url}" failed.';
			trace(msg);
			js.Browser.alert(msg);
		}
	}

	public static function onItemClick(itemId:UInt) {
		if (Id.execute_actions_cb.as(InputElement).checked) {
			websocket.send(haxe.Json.stringify({
				type: click,
				whoami: client,
				itemId: itemId,
			}));
		}
	}

	static function main() {
		new App();
	}
}
