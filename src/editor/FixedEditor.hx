import js.html.Element;
import js.html.Event;
import hx.Selectors.Cls;
import hx.Selectors.Id;

class FixedEditor {
	static var draggingItemId:UInt;

	static var listeners:Array<Utils.Listener> = [];

	public static function show() {
		var fixedItems = App.editorData.layout.fixedItems;

		if (fixedItems == null || fixedItems.length == 0)
			return;

		Utils.clearElement(Id.fixed_content.get());

		for (fi in fixedItems) {
			switch ItemEditor.show(fi) {
				case Some(cell):
					Id.fixed_content.get().append(cell);
					cell.classList.remove(Cls.draggable_item);
				case None:
			}
		}

		var repetition = (fixedItems.length) > 8 ? 8 : fixedItems.length;
		var percentage = 100 / repetition;

		Id.fixed_content.get().style.gridTemplateColumns = 'repeat(${fixedItems.length}, $percentage%)';

		for (d in Cls.draggable_fixed_item.get()) {
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
		var items = App.editorData.layout.fixedItems;
		for (i in 0...items.length) {
			item = items[i];
			if (item == null || item.id == null)
				continue;
			if (item.id.toUInt() == targetItemId)
				targetIndex = i;
			if (item.id.toUInt() == draggingItemId)
				itemToMove = items.splice(i, 1)[0];
		}

		trace('draggingItemId', draggingItemId);
		trace('targetItemId', targetItemId);
		trace('itemToMove', itemToMove);
		trace('targetIndex', targetIndex);

		if (itemToMove != null && targetIndex != -1) {
			items.insert(targetIndex, itemToMove);
			App.dirtyData = true;
			show();
		}
	}
}
