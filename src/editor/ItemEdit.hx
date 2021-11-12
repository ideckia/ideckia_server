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
		var tplDiv = cast Id.item_list_item_tpl.get().cloneNode(true);
		var parentLi:LIElement = cast tplDiv.children[0];
		parentLi.dataset.item_id = Std.string(item.id.toUInt());
		var callback = (item) -> {};
		var text;
		switch item.kind {
			case ChangeDir(toDir, state):
				var ulItems = document.createUListElement();
				var li = StateEdit.show(state);
				ulItems.append(li);
				parentLi.append(ulItems);
				parentLi.getElementsByClassName(Cls.add_state_btn)[0].classList.add(Cls.hidden);
				text = 'DIR --to_dir--> ' + toDir.toString();

				callback = edit;
			case States(_, list):
				var ulItems = document.createUListElement();
				var li;
				text = 'ITEM: ';
				for (state in list) {
					li = StateEdit.show(state);
					ulItems.append(li);
				}
				parentLi.append(ulItems);

				callback = (item) -> App.onItemClick(item.id.toUInt());

			case null:
				text = 'Empty item';
				var createItemBtn = parentLi.getElementsByClassName(Cls.create_item_btn)[0];
				createItemBtn.classList.remove(Cls.hidden);
				createItemBtn.addEventListener('click', (_) -> {
					var changeDirType = 'changedir';
					var statesType = 'states';
					var itemType = js.Browser.window.prompt('What type of item do you want to create?\n-$changeDirType\n-$statesType');

					if (itemType != changeDirType && itemType != statesType) {
						js.Browser.window.alert('$itemType is not a correct item type.');
						return;
					}

					if (itemType == changeDirType) {
						var mainDir = App.editorData.layout.dirs[0];
						item.kind = ChangeDir(mainDir.name, {});
					} else {
						item.kind = States(0, [{}]);
					}

					item.id = Utils.getNextItemId();

					DirEdit.refresh();
				});
		}

		parentLi.getElementsByTagName(Tag.span)[0].innerText = text;
		parentLi.addEventListener('click', (event:Event) -> {
			event.stopImmediatePropagation();
			Utils.selectElement(parentLi);
			Utils.hideProps();

			callback(item);
		});

		parentLi.getElementsByClassName(Cls.add_state_btn)[0].addEventListener('click', (event) -> {
			event.stopImmediatePropagation();
			js.Browser.alert('TODO');
			// var actionNames = [for (a in App.editorData.actionDescriptors) a.name];
			// var actionName = js.Browser.window.prompt('What type of action do you want to add?\n- ${actionNames.join('\n- ')}');

			// if (actionName == null)
			// 	return;
			// if (actionNames.indexOf(actionName) == -1) {
			// 	js.Browser.window.alert('$actionName is not a correct name.');
			// 	return;
			// }
			// state.actions.push({
			// 	name: actionName,
			// 	props: {}
			// });

			DirEdit.refresh();
		});
		parentLi.getElementsByClassName(Cls.delete_btn)[0].addEventListener('click', (event) -> {
			event.stopImmediatePropagation();
			if (js.Browser.window.confirm('Do you want to remove the item?')) {
				js.Browser.alert('TODO');
				trace('delete item');
			}
		});

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
