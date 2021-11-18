import js.html.Event;
import js.html.Element;
import js.html.SelectElement;
import api.internal.ServerApi;
import hx.Selectors.Cls;
import hx.Selectors.Id;
import js.Browser.document;

class DirEdit {
	static var currentDir:Dir;
	static var draggingItemId:UInt;

	static var listeners:Array<Utils.Listener> = [];

	public static function show(dir:Dir) {
		currentDir = dir;

		Id.dir_select.as(SelectElement).selectedIndex = App.editorData.layout.dirs.indexOf(dir);

		Utils.clearElement(Id.dir_content.get());
		@:privateAccess Utils.removeListeners(ItemEdit.cellListeners);

		var rows = dir.rows == null ? App.editorData.layout.rows : dir.rows;
		var columns = dir.columns == null ? App.editorData.layout.columns : dir.columns;
		for (rind in 0...rows) {
			for (cind in 0...columns) {
				var item = dir.items[rind * columns + cind];
				switch ItemEdit.show(item) {
					case Some(cell):
						Id.dir_content.get().append(cell);
					case None:
				}
			}
		}

		Id.dir_content.get().style.gridTemplateColumns = 'repeat($columns, auto)';

		for (d in Cls.draggable.get()) {
			Utils.addListener(listeners, d, 'dragstart', (_) -> onDragStart(d.dataset.item_id));
			Utils.addListener(listeners, d, 'dragover', onDragOver);
			Utils.addListener(listeners, d, 'dragleave', onDragLeave);
			Utils.addListener(listeners, d, 'drop', onDrop);
		}
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
			refresh();
		}
	}

	public static function refresh() {
		Utils.hideProps();
		Utils.removeListeners(listeners);
		show(currentDir);
	}

	public static function edit(dir:Dir) {}
}
