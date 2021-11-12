package;

import js.html.InputElement;
import api.internal.ServerApi;
import js.html.MouseEvent;
import js.html.SelectElement;

using api.IdeckiaApi;
using hx.Selectors;

class App {
	static var websocket:js.html.WebSocket;

	public static var editorData:EditorData;

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
			DirEdit.show(dirs[dirs.length - 1]);
		});

		Id.add_item_btn.get().addEventListener('click', (_) -> {
			switch Utils.createNewItem() {
				case Some(item):
					@:privateAccess DirEdit.currentDir.items.push(item);
					DirEdit.refresh();
				case None:
			}
		});

		Id.add_icon_btn.get().addEventListener('click', (_) -> js.Browser.alert('TODO'));

		Id.save_btn.get().addEventListener('click', (_) -> {
			var msg:EditorMsg = {
				type: EditorMsgType.saveLayout,
				whoami: editor,
				layout: editorData.layout
			};
			websocket.send(tink.Json.stringify(msg));
		});
	}

	static function updateDirsSelect() {
		var dirs = editorData.layout.dirs;
		for (selElement in Cls.dir_select.get()) {
			Utils.fillSelectElement(cast(selElement, SelectElement), [for (i in 0...dirs.length) {value: i, text: dirs[i].name.toString()}]);
		}
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

					updateDirsSelect();
					var dirs = editorData.layout.dirs;
					Id.dir_select.get().addEventListener('change', (event) -> {
						var selectedIndex = Std.parseInt(Id.dir_select.as(SelectElement).value);
						DirEdit.show(dirs[selectedIndex]);
					});

					DirEdit.show(dirs[0]);

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
