package;

import api.internal.ServerApi;
import js.Browser.document;
import js.html.DataListElement;
import js.html.DivElement;
import js.html.DragEvent;
import js.html.Element;
import js.html.Event;
import js.html.FileReader;
import js.html.InputElement;
import js.html.LabelElement;
import js.html.SelectElement;
import js.html.TextAreaElement;

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
	public static var dirtyData(default, set):Bool = false;

	public static function set_dirtyData(dd:Bool) {
		dirtyData = dd;
		if (dd)
			Id.update_server_layout_btn.get().classList.remove(Cls.hidden);
		else
			Id.update_server_layout_btn.get().classList.add(Cls.hidden);
		return dd;
	}

	function new() {
		js.Browser.window.onload = onLoad;
	}

	function onLoad() {
		initWebsocketServer();

		js.Browser.window.addEventListener('beforeunload', (e:Event) -> {
			if (dirtyData) {
				e.preventDefault();
				e.returnValue = false;
			}
		});

		Id.dir_select.get().addEventListener('change', (event) -> {
			if (editorData == null)
				return;
			var selectedIndex = Std.parseInt(Id.dir_select.as(SelectElement).value);
			var currentDir = editorData.layout.dirs[selectedIndex];

			ItemEditor.hide();
			StateEditor.hide();
			ActionEditor.hide();

			DirEditor.show(currentDir);
		});

		Id.add_dir_btn.get().addEventListener('click', (_) -> {
			var layoutRows = editorData.layout.rows;
			var layoutColumns = editorData.layout.columns;

			Id.new_dir_name.as(InputElement).value = '';
			Id.new_dir_rows.as(InputElement).value = Std.string(layoutRows);
			Id.new_dir_columns.as(InputElement).value = Std.string(layoutColumns);

			Dialog.show('New directory', Id.new_dir.get(), () -> {
				return new js.lib.Promise((resolve, reject) -> {
					var newDirName = Id.new_dir_name.as(InputElement).value;
					if (newDirName == null || newDirName == '') {
						js.Browser.alert('Cannot create a directory with empty name.');
						resolve(false);
					}

					var dirs = editorData.layout.dirs;
					if (dirs.filter(d -> d.name.toString() == newDirName).length > 0) {
						js.Browser.alert('Already exists a directory with [$newDirName] name.');
						resolve(false);
					}

					var newDir:Dir = {
						name: new DirName(newDirName),
						items: []
					};

					var newRows = Std.parseInt(Id.new_dir_rows.as(InputElement).value);
					var newColumns = Std.parseInt(Id.new_dir_columns.as(InputElement).value);

					if (newRows != layoutRows)
						newDir.rows = newRows;
					if (newColumns != layoutColumns)
						newDir.columns = newColumns;

					dirs.push(newDir);

					App.dirtyData = true;

					updateDirsSelect(true);
					resolve(true);
				});
			});
		});

		Id.add_item_btn.get().addEventListener('click', (_) -> {
			Utils.createNewItem().then(item -> {
				@:privateAccess DirEditor.currentDir.items.push(item);
				App.dirtyData = true;
				DirEditor.refresh();
			}).catchError(error -> trace(error));
		});

		Id.delete_dir_btn.get().addEventListener('click', (_) -> {
			var currentDir = @:privateAccess DirEditor.currentDir;
			if (js.Browser.window.confirm('Are you sure you want to delete the [${currentDir.name.toString()}] directory?')) {
				var dirs = editorData.layout.dirs;
				dirs.remove(currentDir);
				App.dirtyData = true;
				updateDirsSelect();
			}
		});

		var reader = new FileReader();
		reader.onload = function(e) {
			var cleanResult = new EReg("data:image/.*;base64,", "").replace(reader.result, '');
			Id.new_icon_base64.as(TextAreaElement).value = cleanResult;
		};
		reader.onerror = function(e) {
			trace('Error loading image: ' + e.type);
			Id.new_icon_name.as(InputElement).value = '';
		};

		Id.add_icon_btn.get().addEventListener('click', (_) -> {
			Id.new_icon_name.as(InputElement).value = '';
			Id.new_icon_base64.as(TextAreaElement).value = '';

			Id.new_icon_drop_img.get().addEventListener('drop', (e:DragEvent) -> {
				Utils.stopPropagation(e);

				var dataTransfer = e.dataTransfer;

				if (dataTransfer.files.length > 0) {
					var image = dataTransfer.files.item(0);
					var validTypes = ['image/jpeg', 'image/png', 'image/gif'];

					if (validTypes.indexOf(image.type) == -1) {
						js.Browser.alert('Invalid file type. Must be one of [${validTypes.join(', ')}].');
						return;
					}

					var maxSizeInBytes = 10e6; // 10MB
					if (image.size > maxSizeInBytes) {
						js.Browser.alert("File too large");
						return;
					}

					Id.new_icon_name.as(InputElement).value = image.name;

					reader.readAsDataURL(image);
				}
			});
			Id.new_icon_drop_img.get().addEventListener('dragover', (e) -> Utils.stopPropagation(e));
			Id.new_icon_drop_img.get().addEventListener('dragenter', (e) -> {
				Utils.stopPropagation(e);
				Id.new_icon_drop_img.get().classList.add(Cls.icon_drag_over);
			});
			Id.new_icon_drop_img.get().addEventListener('dragleave', (e) -> {
				Utils.stopPropagation(e);
				Id.new_icon_drop_img.get().classList.remove(Cls.icon_drag_over);
			});
			Dialog.show('New icon', Id.new_icon.get(), () -> {
				return new js.lib.Promise((resolve, reject) -> {
					var iconName = Id.new_icon_name.as(InputElement).value;
					var iconData = Id.new_icon_base64.as(TextAreaElement).value;

					if (iconName == null || iconName == '') {
						js.Browser.alert('The name of the icon can not be empty.');
						resolve(false);
						return;
					}

					if (icons.filter(i -> i.name == iconName).length > 0) {
						js.Browser.alert('Already exists [$iconName] icon in the current list. Select another name, please.');
						resolve(false);
						return;
					}

					if (iconData == null || iconData == '') {
						js.Browser.alert('The base64 of the icon can not be empty. Drag&Drop an image to the area or paste the base64 in the textarea.');
						resolve(false);
						return;
					}

					editorData.layout.icons.push({
						key: iconName,
						value: iconData
					});

					updateIcons();

					App.dirtyData = true;
					resolve(true);
				});
			});
		});

		Id.edit_shared_btn.get().addEventListener('click', (_) -> {
			var container:Element = document.createDivElement();
			var div;
			for (sv in editorData.layout.sharedVars) {
				div = Utils.cloneElement(Id.shared_var_edit.get(), DivElement);

				switch Cls.shared_var_edit_key.firstFromAs(div, InputElement) {
					case Some(svKey):
						svKey.value = sv.key;
					case None:
				}

				switch Cls.shared_var_edit_value.firstFromAs(div, InputElement) {
					case Some(svValue):
						svValue.value = sv.value;
					case None:
				}

				container.appendChild(div);
			}
			Dialog.show('Shared values', container, () -> {
				return new js.lib.Promise((resolveDialog, _) -> {
					var svDivs = Cls.shared_var_edit.from(container);

					var newSharedVars = [];

					for (svDiv in svDivs) {
						switch Cls.shared_var_edit_key.firstFromAs(svDiv, InputElement) {
							case Some(svKey):
								if (svKey.value != '') {
									switch Cls.shared_var_edit_value.firstFromAs(svDiv, InputElement) {
										case Some(svValue):
											newSharedVars.push({key: svKey.value, value: svValue.value});
										case None:
									}
								}

							case None:
						}
					}

					editorData.layout.sharedVars = newSharedVars;
					App.dirtyData = true;

					Dialog.clear(true);

					resolveDialog(true);
				});
			});
		});

		Id.update_server_layout_btn.get().addEventListener('click', (_) -> {
			var rows, columns, maxLength;
			for (dir in editorData.layout.dirs) {
				rows = dir.rows == null ? App.editorData.layout.rows : dir.rows;
				columns = dir.columns == null ? App.editorData.layout.columns : dir.columns;
				maxLength = rows * columns;
				dir.items.splice(maxLength, dir.items.length);
			}

			var msg:EditorMsg = {
				type: EditorMsgType.saveLayout,
				whoami: editor,
				layout: editorData.layout
			};
			websocket.send(tink.Json.stringify(msg));
			dirtyData = false;
			Id.layout_updated.get().classList.remove(Cls.hidden);
			haxe.Timer.delay(() -> {
				Id.layout_updated.get().style.opacity = '0';
				haxe.Timer.delay(() -> {
					Id.layout_updated.get().classList.add(Cls.hidden);
					Id.layout_updated.get().style.opacity = '1';
				}, 3000);
			}, 10);
		});
	}

	public static function updateSharedValues(?newSharedVar:{key:String, value:Any}) {
		var sharedVars = editorData.layout.sharedVars;
		if (sharedVars == null) {
			if (newSharedVar == null)
				return;

			sharedVars = [];
		}

		if (newSharedVar != null) {
			editorData.layout.sharedVars.push(newSharedVar);
		}
		var datalist = Id.shared_vars_datalist.as(DataListElement);
		Utils.clearElement(datalist);

		var opt;
		for (sv in sharedVars) {
			opt = js.Browser.document.createOptionElement();
			opt.value = '$' + sv.key;
			datalist.appendChild(opt);
		}
	}

	static function updateDirsSelect(showLast:Bool = false) {
		var dirs = editorData.layout.dirs;
		for (selElement in Cls.dir_select.get()) {
			Utils.fillSelectElement(cast(selElement, SelectElement), [for (i in 0...dirs.length) {value: i, text: dirs[i].name.toString()}]);
		}

		if (dirs.length > 0) {
			Id.layout_container.get().classList.remove(Cls.hidden);
			Id.delete_dir_btn.get().classList.remove(Cls.hidden);
			if (showLast)
				DirEditor.show(dirs[dirs.length - 1]);
			else
				DirEditor.show(dirs[0]);
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

		websocket.onopen = () -> {}

		websocket.onmessage = (event:{data:Any}) -> {
			var serverData:ServerMsg<Any> = haxe.Json.parse(event.data);
			switch serverData.type {
				case ServerMsgType.layout:
					if (dirtyData)
						return;

					var msg:EditorMsg = {
						type: EditorMsgType.getEditorData,
						whoami: editor
					};
					websocket.send(haxe.Json.stringify(msg));
				case ServerMsgType.editorData:
					trace('Received editor data.');
					editorData = serverData.data;

					updateSharedValues();

					ItemEditor.hide();
					StateEditor.hide();
					ActionEditor.hide();

					updateIcons();

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
