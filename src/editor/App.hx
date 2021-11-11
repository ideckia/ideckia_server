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
		Id.save_btn.get().addEventListener('click', (_) -> {
			var msg:EditorMsg = {
				type: EditorMsgType.saveLayout,
				whoami: editor,
				layout: editorData.layout
			};
			websocket.send(tink.Json.stringify(msg));
		});

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

					var dirs = editorData.layout.dirs;
					for (element in Cls.dir_select.get()) {
						Utils.clearElement(element);
						Utils.fillSelectElement(cast(element, SelectElement), [for (i in 0...dirs.length) {value: i, text: dirs[i].name.toString()}]);
					}

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
