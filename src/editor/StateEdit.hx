import js.html.SelectElement;
import api.internal.ServerApi;
import js.Browser.document;
import js.html.Event;
import js.html.ImageElement;
import js.html.InputElement;
import js.html.LIElement;
import hx.Selectors.Cls;
import hx.Selectors.Id;
import hx.Selectors.Tag;

typedef IconData = {
	var name:String;
	var base64:String;
}

class StateEdit {
	static var originalState:ServerState;
	static var editableState:ServerState;
	static var icons:Array<IconData>;

	public static function show(state:ServerState) {
		var tplDiv = cast Id.state_list_item_tpl.get().cloneNode(true);
		var parentLi:LIElement = cast tplDiv.children[0];
		parentLi.getElementsByTagName(Tag.span)[0].innerText = 'STATE: ' + state.text;

		if (state.actions != null) {
			var ulActions = document.createUListElement();
			for (action in state.actions) {
				ulActions.append(ActionEdit.show(state, action));
			}
			parentLi.append(ulActions);
		}

		parentLi.addEventListener('click', (event:Event) -> {
			event.stopImmediatePropagation();
			Utils.selectElement(parentLi);
			edit(state);
		});

		icons = [
			for (i in App.editorData.layout.icons)
				{
					name: i.key,
					base64: i.value
				}
		];
		icons.insert(0, {name: '', base64: ''});

		parentLi.getElementsByClassName(Cls.add_action_btn)[0].addEventListener('click', (event) -> {
			event.stopImmediatePropagation();
			var actionNames = [for (a in App.editorData.actionDescriptors) a.name];
			var actionName = js.Browser.window.prompt('What type of action do you want to add?\n- ${actionNames.join('\n- ')}');

			if (actionName == null)
				return;
			if (actionNames.indexOf(actionName) == -1) {
				js.Browser.window.alert('$actionName is not a correct name.');
				return;
			}
			state.actions.push({
				name: actionName,
				props: {}
			});

			DirEdit.refresh();
		});
		parentLi.getElementsByClassName(Cls.delete_btn)[0].addEventListener('click', (event) -> {
			event.stopImmediatePropagation();
			if (js.Browser.window.confirm('Do you want to remove the state [${state.text}]?'))
				trace('delete state ${state.text}');
		});

		return parentLi;
	}

	public static function edit(state:ServerState, hideProps:Bool = true) {
		if (state == null) {
			Id.state_properties.get().classList.add(Cls.hidden);
			return;
		}

		if (hideProps)
			Utils.hideProps();
		originalState = state;
		editableState = Reflect.copy(originalState);

		Id.state_properties.get().classList.remove(Cls.hidden);

		Id.text.as(InputElement).value = editableState.text;
		var textColor = editableState.textColor;
		Id.text_color.as(InputElement).value = textColor == null ? '' : '#' + textColor.substr(2);
		var bgColor = editableState.bgColor;
		Id.bg_color.as(InputElement).value = bgColor == null ? '' : '#' + bgColor.substr(2);

		Utils.fillSelectElement(Id.icons.as(SelectElement), [for (i in 0...icons.length) {value: i, text: icons[i].name}]);

		var index = 0;
		if (editableState.icon != null) {
			for (i in 0...icons.length) {
				if (icons[i].name == editableState.icon) {
					index = i;
					break;
				}
			}

			Id.icons.as(SelectElement).selectedIndex = index;
		}
		setIconPreview(icons[index]);

		Id.text.get().addEventListener('change', onTextChange);
		Id.text_color.get().addEventListener('change', onTextColorChange);
		Id.bg_color.get().addEventListener('change', onBgColorChange);
		Id.icons.get().addEventListener('change', onIconChange);

		Id.state_save_btn.get().addEventListener('click', onSaveClick, {once: true});
		Id.state_cancel_btn.get().addEventListener('click', (_) -> hide(), {once: true});
	}

	public static function hide() {
		editableState = null;
		Id.state_save_btn.get().removeEventListener('click', onSaveClick);
		Id.state_properties.get().classList.add(Cls.hidden);
	}

	static function setIconPreview(selectedIcon:IconData) {
		if (selectedIcon.name != '') {
			Id.icon_preview.get().classList.remove(Cls.hidden);
			Id.icon_preview.as(ImageElement).src = 'data:image/jpeg;base64,' + selectedIcon.base64;
		} else {
			Id.icon_preview.get().classList.add(Cls.hidden);
		}
	}

	static function onIconChange(_) {
		if (editableState == null)
			return;
		var selectedIcon = icons[Id.icons.as(SelectElement).selectedIndex];
		editableState.icon = selectedIcon.name;
		setIconPreview(selectedIcon);
	}

	static function onTextChange(_) {
		if (editableState == null)
			return;
		editableState.text = Id.text.as(InputElement).value;
	}

	static function onTextColorChange(_) {
		if (editableState == null)
			return;
		editableState.textColor = Id.text_color.as(InputElement).value;
	}

	static function onBgColorChange(_) {
		if (editableState == null)
			return;
		editableState.bgColor = Id.bg_color.as(InputElement).value;
	}

	static function onSaveClick(_) {
		if (editableState == null)
			return;
		// originalState = Reflect.copy(editableState);
		// trace('onsaveclick: ' + originalState);
		var dirs = App.editorData.layout.dirs;
		for (d in dirs) {
			for (i in d.items) {
				switch i.kind {
					case null:
					case ChangeDir(toDir, state):
						if (state.id == editableState.id)
							i.kind = ChangeDir(toDir, editableState);
					case States(_, list):
						for (sind in 0...list.length) {
							if (list[sind].id == editableState.id)
								list[sind] = editableState;
						}
				}
			}
		}
		Id.text.get().removeEventListener('change', onTextChange);
		Id.text_color.get().removeEventListener('change', onTextColorChange);
		Id.bg_color.get().removeEventListener('change', onBgColorChange);
		Id.icons.get().removeEventListener('change', onIconChange);
		Utils.hideProps();
		DirEdit.refresh();
	}
}
