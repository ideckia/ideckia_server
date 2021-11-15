import js.html.Element;
import api.internal.ServerApi;
import js.Browser.document;
import js.html.Event;
import js.html.SelectElement;
import hx.Selectors.Cls;
import hx.Selectors.Id;
import js.html.LIElement;
import hx.Selectors.Cls;
import hx.Selectors.Id;
import hx.Selectors.Tag;

class ItemEdit {
	static var originalItem:ServerItem;
	static var editableItem:ServerItem;

	static var listeners:Array<Utils.Listener> = [];

	public static function show(item:ServerItem) {
		var parentLi:LIElement = cast Id.item_list_item_tpl.get().cloneNode(true);
		parentLi.removeAttribute('id');
		parentLi.dataset.item_id = Std.string(item.id.toUInt());
		var callback = (item) -> {};
		var text;
		switch item.kind {
			case ChangeDir(toDir, state):
				var ulItems = document.createUListElement();
				var li = StateEdit.show(state, false);
				ulItems.append(li);
				parentLi.append(ulItems);
				switch Cls.add_state_btn.firstFrom(parentLi) {
					case Some(v):
						v.classList.add(Cls.hidden);
					case None:
						trace('No [${Cls.add_state_btn.selector()}] found in [${Id.item_list_item_tpl.selector()}]');
				}
				text = 'DIR --to_dir--> ' + toDir.toString();

				callback = edit;
			case States(_, list):
				var ulItems = document.createUListElement();
				var li;
				text = 'ITEM: ';
				var deletable = list.length > 1;
				for (state in list) {
					li = StateEdit.show(state, deletable);
					ulItems.append(li);
				}
				parentLi.append(ulItems);

				callback = (item) -> App.onItemClick(item.id.toUInt());

			case null:
				text = 'Empty item';
				switch Cls.create_item_btn.firstFrom(parentLi) {
					case Some(v):
						v.classList.remove(Cls.hidden);
						v.addEventListener('click', (_) -> {
							var changeDirType = 'changedir';
							var statesType = 'states';
							var itemType = js.Browser.window.prompt('What type of item do you want to create?\n-$changeDirType\n-$statesType');

							if (itemType != changeDirType && itemType != statesType) {
								js.Browser.window.alert('$itemType is not a correct item type.');
								return;
							}

							if (itemType == changeDirType) {
								var mainDir = App.editorData.layout.dirs[0];
								item.kind = ChangeDir(mainDir.name, Utils.createNewState());
							} else {
								item.kind = States(0, [Utils.createNewState()]);
							}

							item.id = Utils.getNextItemId();

							DirEdit.refresh();
						});
					case None:
						trace('No [${Cls.create_item_btn.selector()}] found in [${Id.item_list_item_tpl.selector()}]');
				}
		}

		switch Tag.span.firstFrom(parentLi) {
			case Some(v):
				v.innerText = text;
			case None:
				trace('No [${Tag.span.selector()}] found in [${Id.item_list_item_tpl.selector()}]');
		}
		parentLi.addEventListener('click', (event:Event) -> {
			event.stopImmediatePropagation();
			Utils.selectElement(parentLi);
			Utils.hideProps();

			callback(item);
		});

		switch Cls.add_state_btn.firstFrom(parentLi) {
			case Some(v):
				v.addEventListener('click', (event) -> {
					event.stopImmediatePropagation();

					switch item.kind {
						case States(_, list):
							list.push(Utils.createNewState());
						default:
					}

					DirEdit.refresh();
				});
			case None:
				trace('No [${Cls.add_state_btn.selector()}] found in [${Id.item_list_item_tpl.selector()}]');
		}
		switch Cls.delete_btn.firstFrom(parentLi) {
			case Some(v):
				v.addEventListener('click', (event) -> {
					event.stopImmediatePropagation();
					if (js.Browser.window.confirm('Do you want to remove the item?')) {
						js.Browser.alert('TODO');
						trace('delete item');
					}
				});
			case None:
				trace('No [${Cls.delete_btn.selector()}] found in [${Id.item_list_item_tpl.selector()}]');
		}
		return parentLi;
	}

	static function edit(item:ServerItem) {
		Utils.removeListeners(listeners);
		originalItem = item;
		editableItem = Reflect.copy(item);
		switch editableItem.kind {
			case ChangeDir(toDir, state):
				var select = Id.to_dir_select.as(SelectElement);
				var children = select.children;
				for (cind in 0...children.length) {
					if (children.item(cind).textContent == toDir.toString()) {
						select.selectedIndex = cind;
					}
				}

				StateEdit.edit(state, false);
				Id.change_dir_properties.get().classList.remove(Cls.hidden);

				Utils.addListener(listeners, select, 'change', onToDirChange);

				Utils.addListener(listeners, Id.change_dir_save_btn.get(), 'click', onSaveClick, true);
				Utils.addListener(listeners, Id.change_dir_cancel_btn.get(), 'click', (_) -> hide(), true);
			case _:
		}
	}

	public static function hide() {
		editableItem = null;
		Utils.removeListeners(listeners);
		Id.change_dir_properties.get().classList.add(Cls.hidden);
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
