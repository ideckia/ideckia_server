import api.internal.ServerApi;
import hx.Selectors.Cls;
import hx.Selectors.Id;
import hx.Selectors.Tag;
import js.Browser.document;
import js.html.DivElement;
import js.html.Event;
import js.html.SelectElement;
import haxe.ds.Option;

class ItemEdit {
	static var originalItem:ServerItem;
	static var editableItem:ServerItem;

	static var listeners:Array<Utils.Listener> = [];
	static var cellListeners:Array<Utils.Listener> = [];

	public static function show(item:ServerItem) {
		if (item == null)
			return None;

		var cell:DivElement = cast Id.layout_grid_item_tpl.get().cloneNode(true);
		cell.removeAttribute('id');
		cell.dataset.item_id = Std.string(item.id.toUInt());
		var callback:ServerItem->Void = (item) -> {};
		if (item != null) {
			var text = '';
			switch item.kind {
				case null:
					text = 'empty';
				case ChangeDir(toDir, state):
					var iconText = (state.icon == null) ? '' : ' / icon: [${state.icon.substr(0, 15)}]';
					text = 'text: [${state.text}]$iconText\ntoDir: ${toDir.toString()}';
					cell.classList.add('dir');
				case States(_, list):
					var state = list[0];
					var iconText = (state.icon == null) ? '' : ' / icon: [${state.icon.substr(0, 15)}]';
					text = 'text: [${state.text}]$iconText';
					cell.classList.add('states');
					callback = (item) -> App.onItemClick(item.id.toUInt());
			};

			switch Tag.span.firstFrom(cell) {
				case Some(v):
					v.innerText = text;
				case None:
					trace('No [${Tag.span.selector()}] found in [${Id.layout_grid_item_tpl.selector()}]');
			}
		}

		Utils.addListener(cellListeners, cell, 'click', (event:Event) -> {
			event.stopImmediatePropagation();
			Utils.selectElement(cell);
			Utils.hideProps();

			callback(item);
			edit(item);
		});

		return Some(cell);
	}

	static function edit(item:ServerItem) {
		hide();
		originalItem = item;
		editableItem = Reflect.copy(item);

		Utils.addListener(listeners, Id.add_state_btn.get(), 'click', (event) -> {
			event.stopImmediatePropagation();

			switch item.kind {
				case States(_, list):
					list.push(Utils.createNewState());
				default:
			}

			edit(item);
		});

		Utils.addListener(listeners, Id.clear_item_btn.get(), 'click', (event) -> {
			event.stopImmediatePropagation();
			if (js.Browser.window.confirm('Do you want to clear the item?')) {
				item.kind = null;
				DirEdit.refresh();
			}
		});
		Id.item_container.get().classList.remove(Cls.hidden);
		Id.add_item_kind_btn.get().classList.add(Cls.hidden);
		Id.add_state_btn.get().classList.add(Cls.hidden);
		Id.clear_item_btn.get().classList.add(Cls.hidden);
		switch editableItem.kind {
			case ChangeDir(toDir, state):
				Id.add_state_btn.get().classList.add(Cls.hidden);
				Id.clear_item_btn.get().classList.remove(Cls.hidden);
				var select = Id.to_dir_select.as(SelectElement);
				var children = select.children;
				for (cind in 0...children.length) {
					if (children.item(cind).textContent == toDir.toString()) {
						select.selectedIndex = cind;
					}
				}

				StateEdit.edit(state);
				Id.item_kind_changedir_properties.get().classList.remove(Cls.hidden);

				Utils.addListener(listeners, select, 'change', onToDirChange);

				Utils.addListener(listeners, Id.change_dir_save_btn.get(), 'click', onSaveClick, true);
				Utils.addListener(listeners, Id.change_dir_cancel_btn.get(), 'click', (_) -> hide(), true);
			case States(_, list):
				Id.add_state_btn.get().classList.remove(Cls.hidden);
				Id.clear_item_btn.get().classList.remove(Cls.hidden);
				var parentDiv = Id.item_kind_states_properties.get();
				Utils.clearElement(parentDiv);
				var ulLabel = document.createLabelElement();
				ulLabel.textContent = "STATES";
				parentDiv.append(ulLabel);
				var uList = document.createUListElement();
				var li;
				var deletable = list.length > 1;
				for (state in list) {
					li = StateEdit.show(state, deletable);
					uList.append(li);
				}
				parentDiv.append(uList);

				Utils.addListener(listeners, Id.add_state_btn.get(), 'click', (_) -> {});
			case null:
				Id.add_item_kind_btn.get().classList.remove(Cls.hidden);
				Utils.addListener(listeners, Id.add_item_kind_btn.get(), 'click', (_) -> {
					switch Utils.createNewItem() {
						case Some(newItem):
							item.id = newItem.id;
							item.kind = newItem.kind;

							edit(item);

						// DirEdit.refresh();
						case None:
					};
				});
		}
	}

	public static function hide() {
		editableItem = null;
		Utils.removeListeners(listeners);
		Id.item_container.get().classList.add(Cls.hidden);
		Id.item_kind_changedir_properties.get().classList.add(Cls.hidden);
	}

	static function onToDirChange(_) {
		switch editableItem.kind {
			case ChangeDir(_, state):
				var select = Id.to_dir_select.as(SelectElement);
				var children = select.children;
				editableItem.kind = ChangeDir(new DirName(children[select.selectedIndex].textContent), state);
			case _:
		}
	}

	static function onSaveClick(_) {
		if (editableItem == null)
			return;
		originalItem.kind = Reflect.copy(editableItem.kind);
		hide();
		Utils.hideProps();
		DirEdit.refresh();
	}
}
