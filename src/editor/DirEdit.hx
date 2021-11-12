import js.html.Event;
import js.html.Element;
import js.html.SelectElement;
import api.internal.ServerApi;
import hx.Selectors.Cls;
import hx.Selectors.Id;
import js.Browser.document;

class DirEdit {
	static var currentDir:Dir;
	static var dragginItemId:UInt;

	static var listeners:Array<Utils.Listener> = [];

	public static function show(dir:Dir) {
		currentDir = dir;

		Id.dir_select.as(SelectElement).selectedIndex = App.editorData.layout.dirs.indexOf(dir);

		Utils.clearElement(Id.dir_content.get());

		var ulItems = document.createUListElement();
		for (item in currentDir.items) {
			ulItems.append(ItemEdit.show(item));
		}

		Id.dir_content.get().append(ulItems);

		for (d in Cls.draggable.get()) {
			Utils.addListener(listeners, d, 'dragstart', (_) -> onDragStart(d.dataset.item_id));
			Utils.addListener(listeners, d, 'dragover', onDragOver);
			Utils.addListener(listeners, d, 'dragleave', onDragLeave);
			Utils.addListener(listeners, d, 'drop', onDrop);
		}
	}

	static function onDragStart(itemId:String) {
		dragginItemId = Std.parseInt(itemId);
	}

	static function onDragOver(e:Event) {
		e.preventDefault();
		var targetElement = cast(e.currentTarget, Element);
		if (!targetElement.classList.contains(Cls.drag_over))
			targetElement.classList.add(Cls.drag_over);
	}

	static function onDragLeave(e:Event) {
		e.preventDefault();
		var targetElement = cast(e.currentTarget, Element);
		targetElement.classList.remove(Cls.drag_over);
	}

	static function onDrop(e:Event) {
		for (d in Cls.drag_over.get())
			d.classList.remove(Cls.drag_over);
		var targetItemId = Std.parseInt(cast(e.currentTarget, Element).dataset.item_id);

		var itemToMove = null;
		var item;
		var targetIndex = -1;
		for (i in 0...currentDir.items.length) {
			item = currentDir.items[i];
			if (item == null || item.id == null)
				continue;
			if (item.id.toUInt() == targetItemId)
				targetIndex = i;
			if (item.id.toUInt() == dragginItemId)
				itemToMove = currentDir.items.splice(i, 1)[0];
		}

		if (itemToMove != null && targetIndex != -1) {
			currentDir.items.insert(targetIndex, itemToMove);
			refresh();
		}
	}

	public static function refresh() {
		Utils.hideProps();
		Utils.removeListeners(listeners);
		show(currentDir);
	}

	public static function edit(dir:Dir) {}
	/*
		function showInGrid(dirName:String) {
			for (element in document.getElementsByClassName('is-active')) {
				element.classList.remove('is-active');
			}
			Utils.clearElement(Id.container.get());

			var layout = editorData.layout;
			var found = layout.dirs.filter(f -> f.name.toString() == dirName);
			if (found.length == 0)
				return;

			var dir = found[0];
			var items = dir.items;
			var rows = dir.rows == null ? layout.rows : dir.rows;
			var columns = dir.columns == null ? layout.columns : dir.columns;
			var gridTemplateColumns = '';
			for (rind in 0...rows) {
				gridTemplateColumns = '';
				for (cind in 0...columns) {
					gridTemplateColumns += 'auto ';
					var item = items[rind * columns + cind];
					var cell = document.createDivElement();
					if (item != null) {
						switch item.kind {
							case null:
								cell.innerText = 'empty';
							case ChangeDir(toDir, _):
								cell.innerText = 'dir: ${toDir.toString()}';
								cell.classList.add('dir');
							case States(_, list):
								cell.innerText = 'states: ${list[0].text}';
								cell.classList.add('states');
						};
						cell.id = Std.string(item.id);
					}

					cell.classList.add('grid-item');

					cell.onclick = onItemSelected.bind(item);
					cell.classList.add(Cls.clickable_item);
					Id.container.get().append(cell);
				}
			}

			Id.container.get().style.gridTemplateColumns = gridTemplateColumns;
			document.getElementById(dirName).classList.add('is-active');
		}
	 */
}
