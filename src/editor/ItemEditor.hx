import js.html.Element;
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
	static var isFixedItem:Bool;
	static var draggingStateIndex:UInt;
	static var listeners:Array<Utils.Listener> = [];
	static var cellListeners:Array<Utils.Listener> = [];

	public static function show(item:ServerItem, isFixed:Bool = false):Option<Element> {
		if (item == null)
			return None;

		var cell = Utils.cloneElement(Id.layout_grid_item_tpl.get(), DivElement);
		cell.dataset.item_id = Std.string(item.id.toUInt());
		var executionCallback:ServerItem->Void = (item) -> {};
		var longPressCallback:ServerItem->Void = (item) -> {};

		var text = '';
		var textPosition = Cls.layout_bottom_text;
		var textColor = 'white';
		switch item.kind {
			case null:
				text = 'empty';
			case ChangeDir(_, state):
				switch Cls.item_icon.firstFrom(cell) {
					case Some(cell_icon):
						if (state.icon != null && state.icon != '') {
							cell_icon.classList.remove(Cls.hidden);
							cast(cell_icon, ImageElement).src = extractIcon(state);
						} else {
							cell_icon.classList.add(Cls.hidden);
						}
					case None:
				}
				text = state.text;
				textPosition = switch state.textPosition {
					case top: Cls.layout_top_text;
					case center: Cls.layout_center_text;
					default: Cls.layout_bottom_text;
				}
				if (state.textColor != null) {
					textColor = '#' + state.textColor.substr(2);
				}
				if (state.bgColor != null) {
					cell.style.backgroundColor = '#' + state.bgColor.substr(2);
				} else {
					cell.classList.add('dir');
				}
			case States(index, list):
				if (index == null)
					index = 0;
				var state = list[index];
				switch Cls.item_icon.firstFrom(cell) {
					case Some(cell_icon):
						if (state.icon != null && state.icon != '') {
							cell_icon.classList.remove(Cls.hidden);
							cast(cell_icon, ImageElement).src = extractIcon(state);
						} else {
							cell_icon.classList.add(Cls.hidden);
						}
					case None:
				}
				text = state.text;
				textPosition = switch state.textPosition {
					case top: Cls.layout_top_text;
					case center: Cls.layout_center_text;
					default: Cls.layout_bottom_text;
				}
				if (state.textColor != null) {
					textColor = '#' + state.textColor.substr(2);
				}
				if (state.bgColor != null) {
					cell.style.backgroundColor = '#' + state.bgColor.substr(2);
				} else {
					cell.classList.add('states');
				}
				executionCallback = (item) -> App.onItemClick(item.id.toUInt());
				longPressCallback = (item) -> App.onItemLongPress(item.id.toUInt());
		};

		switch Cls.item_text_div.firstFrom(cell) {
			case Some(v):
				v.classList.add(textPosition);
			case None:
		}

		switch Tag.span.firstFrom(cell) {
			case Some(v):
				v.innerText = text;
				v.style.color = textColor;
			case None:
				trace('No [${Tag.span.selector()}] found in [${Id.layout_grid_item_tpl.selector()}]');
		}

		cell.addEventListener('click', (event:Event) -> {
			Utils.stopPropagation(event);
			Utils.selectElement(cell);
			Utils.hideAllProps();

			executionCallback(item);
			edit(item, isFixed);
		});
		cell.addEventListener('contextmenu', (event:Event) -> {
			longPressCallback(item);
		});

		return Some(cell);
	}

	static function extractIcon(state) {
		var base64Icon = switch Utils.getIconIndexByName(state.icon) {
			case Some(index):
				App.icons[index].base64;
			case None:
				state.icon;
		};

		return Utils.defaultBase64Prefix(base64Icon);
	}

	public static function refresh() {
		var oldItem = editingItem;
		hide();
		edit(oldItem, isFixedItem);
	}

	public static function edit(item:ServerItem, isFixed:Bool) {
		editingItem = item;
		isFixedItem = isFixed;

		Utils.addListener(listeners, Id.add_state_btn.get(), 'click', (event) -> {
			Utils.stopPropagation(event);

			switch editingItem.kind {
				case States(_, list):
					var state = Utils.createNewState();
					list.push(state);
					edit(editingItem, isFixedItem);
					StateEditor.edit(state);
				default:
			}
		});

		Utils.addListener(listeners, Id.clear_item_btn.get(), 'click', (event) -> {
			Utils.stopPropagation(event);
			if (js.Browser.window.confirm('Do you want to CLEAR the item?')) {
				editingItem.kind = null;
				App.dirtyData = true;
				StateEditor.hide();
				ItemEditor.hide();
				ActionEditor.hide();
				DirEditor.refresh();
				FixedEditor.show();
			}
		});

		if (isFixed) {
			Id.remove_item_btn.get().classList.remove(Cls.hidden);
			Utils.addListener(listeners, Id.remove_item_btn.get(), 'click', (event) -> {
				Utils.stopPropagation(event);
				if (js.Browser.window.confirm('Do you want to REMOVE the item?')) {
					editingItem.kind = null;

					function removeItem(items:Array<ServerItem>) {
						for (i in items) {
							if (i.id == editingItem.id) {
								items.remove(i);
								return true;
							}
						}
						return false;
					}

					if (!removeItem(@:privateAccess DirEditor.currentDir.items)) {
						removeItem(App.editorData.layout.fixedItems);
					}
					App.dirtyData = true;
					StateEditor.hide();
					ItemEditor.hide();
					ActionEditor.hide();
					DirEditor.refresh();
					FixedEditor.show();
				}
			});
		} else {
			Id.remove_item_btn.get().classList.add(Cls.hidden);
		}

		Id.item_container.get().classList.remove(Cls.hidden);
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
				for (i in 0...list.length) {
					li = StateEditor.show(list[i], deletable);
					li.dataset.state_id = Std.string(i);
					uList.append(li);
				}
				parentDiv.append(uList);
				for (d in Cls.draggable_state.from(uList)) {
					Utils.addListener(listeners, d, 'dragstart', (_) -> onDragStart(d.dataset.state_id));
					Utils.addListener(listeners, d, 'dragover', onDragOver);
					Utils.addListener(listeners, d, 'dragleave', onDragLeave);
					Utils.addListener(listeners, d, 'drop', (e) -> onDrop(e, item));
				}

				Utils.addListener(listeners, Id.add_state_btn.get(), 'click', (_) -> {});
			case null:
				Id.add_item_kind_btn.get().classList.remove(Cls.hidden);
				Utils.addListener(listeners, Id.add_item_kind_btn.get(), 'click', (_) -> {
					Utils.createNewItem().then((newItem) -> {
						editingItem.id = newItem.id;
						editingItem.kind = newItem.kind;
						App.dirtyData = true;
						DirEditor.refresh();
						refresh();
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
				App.dirtyData = true;
			case _:
		}
	}

	static function onDragStart(stateId:String) {
		draggingStateIndex = Std.parseInt(stateId);
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

	static function onDrop(e:Event, item:ServerItem) {
		for (d in Cls.drag_over.get())
			d.classList.remove(Cls.drag_over);
		var targetStateIndex = Std.parseInt(cast(e.currentTarget, Element).dataset.state_id);

		switch item.kind {
			case States(index, list):
				var stateToMove = list.splice(draggingStateIndex, 1)[0];
				if (stateToMove != null) {
					list.insert(targetStateIndex, stateToMove);
					item.kind = States(index, list);
					App.dirtyData = true;
					DirEditor.refresh();
					refresh();
				}
			case _:
		}
	}
}
