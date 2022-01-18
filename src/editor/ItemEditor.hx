import js.html.ImageElement;
import api.internal.ServerApi;
import hx.Selectors.Cls;
import hx.Selectors.Id;
import hx.Selectors.Tag;
import js.Browser.document;
import js.html.DivElement;
import js.html.Event;
import js.html.SelectElement;
import haxe.ds.Option;

class ItemEditor {
	static var editingItem:ServerItem;
	static var listeners:Array<Utils.Listener> = [];
	static var cellListeners:Array<Utils.Listener> = [];

	public static function show(item:ServerItem) {
		if (item == null)
			return None;

		var cell:DivElement = cast Id.layout_grid_item_tpl.get().cloneNode(true);
		cell.removeAttribute('id');
		cell.dataset.item_id = Std.string(item.id.toUInt());
		var callback:ServerItem->Void = (item) -> {};

		var text = '';
		var textColor = 'white';
		switch item.kind {
			case null:
				text = 'empty';
			case ChangeDir(_, state):
				switch Cls.item_icon.firstFrom(cell) {
					case Some(cell_icon):
						if (state.icon != null && state.icon != '') {
							cell_icon.classList.remove(Cls.hidden);
							switch Utils.getIconIndexByName(state.icon) {
								case Some(index):
									cast(cell_icon, ImageElement).src = 'data:image/jpeg;base64,' + App.icons[index].base64;
								case None:
									cast(cell_icon, ImageElement).src = 'data:image/jpeg;base64,' + state.icon;
							};
						} else {
							cell_icon.classList.add(Cls.hidden);
						}
					case None:
				}
				text = state.text;
				if (state.textColor != null) {
					textColor = '#' + state.textColor.substr(2);
				}
				if (state.bgColor != null) {
					cell.style.backgroundColor = '#' + state.bgColor.substr(2);
				} else {
					cell.classList.add('dir');
				}
			case States(_, list):
				var state = list[0];
				switch Cls.item_icon.firstFrom(cell) {
					case Some(cell_icon):
						if (state.icon != null && state.icon != '') {
							cell_icon.classList.remove(Cls.hidden);
							switch Utils.getIconIndexByName(state.icon) {
								case Some(index):
									cast(cell_icon, ImageElement).src = 'data:image/jpeg;base64,' + App.icons[index].base64;
								case None:
									cast(cell_icon, ImageElement).src = 'data:image/jpeg;base64,' + state.icon;
							};
						} else {
							cell_icon.classList.add(Cls.hidden);
						}
					case None:
				}
				text = state.text;
				if (state.textColor != null) {
					textColor = '#' + state.textColor.substr(2);
				}
				if (state.bgColor != null) {
					cell.style.backgroundColor = '#' + state.bgColor.substr(2);
				} else {
					cell.classList.add('states');
				}
				callback = (item) -> App.onItemClick(item.id.toUInt());
		};

		switch Tag.span.firstFrom(cell) {
			case Some(v):
				v.innerText = text;
				v.style.color = textColor;
			case None:
				trace('No [${Tag.span.selector()}] found in [${Id.layout_grid_item_tpl.selector()}]');
		}

		Utils.addListener(cellListeners, cell, 'click', (event:Event) -> {
			Utils.stopPropagation(event);
			Utils.selectElement(cell);
			Utils.hideAllProps();

			callback(item);
			edit(item);
		});

		return Some(cell);
	}

	public static function refresh() {
		edit(editingItem);
	}

	public static function edit(item:ServerItem) {
		editingItem = item;

		Utils.addListener(listeners, Id.add_state_btn.get(), 'click', (event) -> {
			Utils.stopPropagation(event);

			switch editingItem.kind {
				case States(_, list):
					var state = Utils.createNewState();
					list.push(state);
					edit(editingItem);
					StateEditor.edit(state);
				default:
			}
		});

		Utils.addListener(listeners, Id.clear_item_btn.get(), 'click', (event) -> {
			Utils.stopPropagation(event);
			if (js.Browser.window.confirm('Do you want to clear the item?')) {
				editingItem.kind = null;
				App.dirtyData = true;
				DirEditor.refresh();
			}
		});
		Id.item_container.get().classList.remove(Cls.hidden);
		Id.add_item_kind_btn.get().classList.add(Cls.hidden);
		Id.add_state_btn.get().classList.add(Cls.hidden);
		Id.clear_item_btn.get().classList.add(Cls.hidden);
		Id.item_kind_changedir_properties.get().classList.add(Cls.hidden);
		Id.item_kind_states_properties.get().classList.add(Cls.hidden);
		Id.add_item_kind_btn.get().classList.add(Cls.hidden);
		switch editingItem.kind {
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

				StateEditor.edit(state);
				Id.item_kind_changedir_properties.get().classList.remove(Cls.hidden);

				Utils.addListener(listeners, select, 'change', onToDirChange);
			case States(_, list):
				Id.add_state_btn.get().classList.remove(Cls.hidden);
				Id.clear_item_btn.get().classList.remove(Cls.hidden);
				var parentDiv = Id.item_kind_states_properties.get();
				parentDiv.classList.remove(Cls.hidden);
				Utils.clearElement(parentDiv);
				var ulLabel = document.createLabelElement();
				ulLabel.textContent = "STATES";
				parentDiv.append(ulLabel);
				var uList = document.createUListElement();
				var li;
				var deletable = list.length > 1;
				for (state in list) {
					li = StateEditor.show(state, deletable);
					uList.append(li);
				}
				parentDiv.append(uList);

				Utils.addListener(listeners, Id.add_state_btn.get(), 'click', (_) -> {});
			case null:
				Id.add_item_kind_btn.get().classList.remove(Cls.hidden);
				Utils.addListener(listeners, Id.add_item_kind_btn.get(), 'click', (_) -> {
					Utils.createNewItem().then((newItem) -> {
						editingItem.id = newItem.id;
						editingItem.kind = newItem.kind;
						App.dirtyData = true;
						DirEditor.refresh();
						edit(editingItem);
						return;
					}).catchError(error -> trace(error));
				});
		}
	}

	public static function hide() {
		editingItem = null;
		Utils.removeListeners(listeners);
		Id.item_container.get().classList.add(Cls.hidden);
		Id.item_kind_changedir_properties.get().classList.add(Cls.hidden);
	}

	static function onToDirChange(_) {
		switch editingItem.kind {
			case ChangeDir(_, state):
				var select = Id.to_dir_select.as(SelectElement);
				var children = select.children;
				editingItem.kind = ChangeDir(new DirName(children[select.selectedIndex].textContent), state);
			case _:
		}
	}
}
