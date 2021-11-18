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

class StateEdit {
	static var originalState:ServerState;
	static var editableState:ServerState;

	static var listeners:Array<Utils.Listener> = [];

	public static function show(state:ServerState, deletable:Bool) {
		Id.item_kind_states_properties.get().classList.remove(Cls.hidden);
		var parentLi:LIElement = cast Id.state_list_item_tpl.get().cloneNode(true);
		parentLi.removeAttribute('id');
		switch Tag.span.firstFrom(parentLi) {
			case Some(v):
				var iconText = (state.icon == null) ? '' : ' / icon: [${state.icon.substr(0, 30)}]';
				v.innerText = 'text: [${state.text}]$iconText';
			case None:
				trace('No [${Tag.span.selector()}] found in [${Id.state_list_item_tpl.selector()}]');
		}

		if (!deletable)
			switch Cls.delete_btn.firstFrom(parentLi) {
				case Some(v):
					v.classList.add(Cls.hidden);
				case None:
					trace('No [${Cls.delete_btn.selector()}] found in [${Id.state_list_item_tpl.selector()}]');
			};

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

		switch Cls.add_action_btn.firstFrom(parentLi) {
			case Some(v):
				v.addEventListener('click', (event) -> {
					event.stopImmediatePropagation();
					var actionNames = [for (a in App.editorData.actionDescriptors) a.name];
					var actionName = js.Browser.window.prompt('What type of action do you want to add?\n- ${actionNames.join('\n- ')}');

					if (actionName == null)
						return;
					if (actionNames.indexOf(actionName) == -1) {
						js.Browser.window.alert('$actionName is not a correct name.');
						return;
					}
					if (state.actions == null) {
						state.actions = [];
					}
					state.actions.push({
						name: actionName,
						props: {
							id: Utils.getNextStateId()
						}
					});

					DirEdit.refresh();
				});
			case None:
				trace('No [${Cls.add_action_btn.selector()}] found in [${Id.state_list_item_tpl.selector()}]');
		}

		switch Cls.delete_btn.firstFrom(parentLi) {
			case Some(v):
				v.addEventListener('click', (event) -> {
					event.stopImmediatePropagation();

					if (js.Browser.window.confirm('Do you want to remove the state [${state.text}]?')) {
						trace('delete state ${state.id}');
						for (d in App.editorData.layout.dirs) {
							for (i in d.items) {
								switch i.kind {
									case States(_, list):
										for (sind in 0...list.length)
											if (list[sind].id == state.id)
												list.remove(state);
									default:
								}
							}
						}
					}

					DirEdit.refresh();
				});
			case None:
				trace('No [${Cls.delete_btn.selector()}] found in [${Id.state_list_item_tpl.selector()}]');
		}
		return parentLi;
	}

	public static function edit(state:ServerState) {
		if (state == null) {
			Id.state_properties.get().classList.add(Cls.hidden);
			return;
		}

		ActionEdit.hide();

		Utils.removeListeners(listeners);
		originalState = state;
		editableState = Reflect.copy(originalState);

		Id.state_properties.get().classList.remove(Cls.hidden);

		Id.text.as(InputElement).value = editableState.text;
		var textColor = editableState.textColor;
		Id.text_color.as(InputElement).value = textColor == null ? '' : '#' + textColor.substr(2);
		var bgColor = editableState.bgColor;
		Id.bg_color.as(InputElement).value = bgColor == null ? '' : '#' + bgColor.substr(2);

		Utils.fillSelectElement(Id.icons.as(SelectElement), [for (i in 0...App.icons.length) {value: i, text: App.icons[i].name}]);

		var index = 0;
		if (editableState.icon != null) {
			for (i in 0...App.icons.length) {
				if (App.icons[i].name == editableState.icon) {
					index = i;
					break;
				}
			}

			Id.icons.as(SelectElement).selectedIndex = index;
		}
		setIconPreview(App.icons[index]);

		Utils.addListener(listeners, Id.text.get(), 'change', onTextChange);
		Utils.addListener(listeners, Id.text_color.get(), 'change', onTextColorChange);
		Utils.addListener(listeners, Id.bg_color.get(), 'change', onBgColorChange);
		Utils.addListener(listeners, Id.icons.get(), 'change', onIconChange);

		Utils.addListener(listeners, Id.state_save_btn.get(), 'click', onSaveClick, true);
		Utils.addListener(listeners, Id.state_cancel_btn.get(), 'click', (_) -> hide(), true);
	}

	public static function hide() {
		editableState = null;
		Utils.removeListeners(listeners);
		Id.state_properties.get().classList.add(Cls.hidden);
	}

	static function setIconPreview(selectedIcon:App.IconData) {
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
		var selectedIcon = App.icons[Id.icons.as(SelectElement).selectedIndex];
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
		for (d in App.editorData.layout.dirs) {
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
		hide();
		Utils.hideProps();
		DirEdit.refresh();
	}
}
