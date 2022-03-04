import js.html.InputElement;
import api.internal.ServerApi;
import hx.Selectors.Cls;
import hx.Selectors.Id;
import js.Browser.document;
import js.html.Element;
import js.html.Event;
import js.html.SelectElement;

class DirEditor {
	static var currentDir:Dir;
	static var draggingItemId:UInt;

	static var listeners:Array<Utils.Listener> = [];

	public static function show(dir:Dir) {
		currentDir = dir;
		Id.dir_select.as(SelectElement).selectedIndex = App.editorData.layout.dirs.indexOf(dir);

		Utils.clearElement(Id.dir_content.get());
		@:privateAccess Utils.removeListeners(ItemEditor.cellListeners);

		var rows = dir.rows == null ? App.editorData.layout.rows : dir.rows;
		var columns = dir.columns == null ? App.editorData.layout.columns : dir.columns;
		for (rind in 0...rows) {
			for (cind in 0...columns) {
				var item = dir.items[rind * columns + cind];
				switch ItemEditor.show(item) {
					case Some(cell):
						Id.dir_content.get().append(cell);
						cell.classList.remove(Cls.draggable_fixed_item);
					case None:
				}
			}
		}

		Id.dir_content.get().style.gridTemplateColumns = 'repeat($columns, auto)';

		var rowsInput = Id.current_dir_rows.as(InputElement);
		var columnsInput = Id.current_dir_columns.as(InputElement);
		rowsInput.value = Std.string(rows);
		columnsInput.value = Std.string(columns);

		Utils.addListener(listeners, rowsInput, 'change', (_) -> {
			currentDir.rows = Std.parseInt(rowsInput.value);
			addMissingItems();
		});

		Utils.addListener(listeners, columnsInput, 'change', (_) -> {
			currentDir.columns = Std.parseInt(columnsInput.value);
			addMissingItems();
		});

		for (d in Cls.draggable_item.get()) {
			Utils.addListener(listeners, d, 'dragstart', (_) -> onDragStart(d.dataset.item_id));
			Utils.addListener(listeners, d, 'dragover', onDragOver);
			Utils.addListener(listeners, d, 'dragleave', onDragLeave);
			Utils.addListener(listeners, d, 'drop', onDrop);
		}
	}

	static function addMissingItems() {
		var rows = currentDir.rows == null ? App.editorData.layout.rows : currentDir.rows;
		var columns = currentDir.columns == null ? App.editorData.layout.columns : currentDir.columns;
		while (currentDir.items.length < rows * columns) {
			currentDir.items.push({id: Utils.getNextItemId()});
		}
		App.dirtyData = true;
		refresh();
	}

	static function onDragStart(itemId:String) {
		draggingItemId = Std.parseInt(itemId);
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
			if (item.id.toUInt() == draggingItemId)
				itemToMove = currentDir.items.splice(i, 1)[0];
		}

		if (itemToMove != null && targetIndex != -1) {
			currentDir.items.insert(targetIndex, itemToMove);
			App.dirtyData = true;
			refresh();
		}
	}

	public static function refresh() {
		Utils.removeListeners(listeners);
		show(currentDir);
	}
}
