import api.IdeckiaApi;
import api.internal.ServerApi;
import js.html.DivElement;
import js.html.Element;
import js.html.Event;
import js.html.InputElement;
import js.html.LIElement;
import js.html.SelectElement;
import js.html.SpanElement;
import hx.Selectors.Cls;
import hx.Selectors.Id;
import hx.Selectors.Tag;

using StringTools;

class ActionEdit {
	static var originalAction:Action;
	static var editableActionProps:Any;
	static var changeListeners:Array<{element:Element, changeListener:Event->Void}> = [];
	static var listeners:Array<Utils.Listener> = [];

	public static function show(action:Action, parentState:ServerState) {
		var li:LIElement = cast Id.action_list_item_tpl.get().cloneNode(true);
		li.removeAttribute('id');
		switch Tag.span.firstFrom(li) {
			case Some(v):
				v.innerText = action.name;
			case None:
				trace('No [${Tag.span.selector()}] found in [${Id.action_list_item_tpl.selector()}]');
		}
		li.addEventListener('click', (event:Event) -> {
			event.stopImmediatePropagation();
			Utils.selectElement(li);
			edit(action);
		});

		switch Cls.delete_btn.firstFrom(li) {
			case Some(v):
				v.addEventListener('click', (event) -> {
					event.stopImmediatePropagation();
					if (js.Browser.window.confirm('Do you want to remove the action [${action.name}]?')) {
						parentState.actions.remove(action);
						Utils.hideAllProps();
						App.dirtyData = true;
						DirEdit.refresh();
					}
				});
			case None:
				trace('No [${Cls.delete_btn.selector()}] found in [${Id.action_list_item_tpl.selector()}]');
		}

		return li;
	}

	public static function edit(action:Action) {
		Utils.removeListeners(listeners);
		switch getActionDescriptorByName(action.name) {
			case None:
				trace('Descriptor not found for [${action.name}]');
			case Some(actionDescriptor):
				Id.action_cancel_btn.get().classList.add(Cls.hidden);
				Id.action_accept_btn.get().classList.add(Cls.hidden);
				Utils.clearElement(Id.action_props.get());
				originalAction = action;
				editableActionProps = Reflect.copy(action.props);
				var fieldValue;
				Id.action_properties.get().classList.remove(Cls.hidden);
				for (div in createFromDescriptor(actionDescriptor)) {
					if (!Reflect.hasField(editableActionProps, div.id))
						continue;

					var valueInput:InputElement = cast div.querySelector(Cls.prop_value.selector());
					var possibleValuesSelect:SelectElement = cast div.querySelector(Cls.prop_possible_values.selector());
					var booleanValueInput:InputElement = cast div.querySelector(Cls.prop_bool_value.selector());
					fieldValue = Reflect.field(editableActionProps, div.id);
					if (!valueInput.classList.contains(Cls.hidden)) {
						if (Std.string(fieldValue) == '[object Object]')
							valueInput.value = haxe.Json.stringify(fieldValue);
						else
							valueInput.value = fieldValue;

						Utils.addListener(listeners, valueInput, 'change', (_) -> {
							showCancelAccept();
							var value = valueInput.value;
							Reflect.setField(editableActionProps, div.id, (valueInput.type == 'number') ? Std.parseFloat(value) : value);
						});
					} else if (!possibleValuesSelect.classList.contains(Cls.hidden)) {
						var children = possibleValuesSelect.children;
						for (cind in 0...children.length) {
							if (children.item(cind).textContent == fieldValue) {
								possibleValuesSelect.selectedIndex = cind;
							}
						}

						Utils.addListener(listeners, possibleValuesSelect, 'change', (_) -> {
							showCancelAccept();
							Reflect.setField(editableActionProps, div.id, children[possibleValuesSelect.selectedIndex].textContent);
						});
					} else {
						booleanValueInput.checked = Std.string(fieldValue) == 'true';
						Utils.addListener(listeners, booleanValueInput, 'change', (_) -> {
							showCancelAccept();
							Reflect.setField(editableActionProps, div.id, booleanValueInput.checked);
						});
					}

					Id.action_props.get().appendChild(div);
				}

				Utils.addListener(listeners, Id.action_accept_btn.get(), 'click', onSaveClick, true);
				Utils.addListener(listeners, Id.action_cancel_btn.get(), 'click', (_) -> hide(), true);
		}
	}

	public static function hide() {
		editableActionProps = null;
		Utils.removeListeners(listeners);
		Id.action_properties.get().classList.add(Cls.hidden);
	}

	static function showCancelAccept() {
		Id.change_dir_cancel_btn.get().classList.remove(Cls.hidden);
		Id.change_dir_accept_btn.get().classList.remove(Cls.hidden);
	}

	static function onSaveClick(_) {
		if (editableActionProps == null)
			return;
		originalAction.props = Reflect.copy(editableActionProps);
		hide();
		App.dirtyData = true;
		DirEdit.refresh();
	}

	static function getActionDescriptorByName(actionName:String):haxe.ds.Option<ActionDescriptor> {
		var f = App.editorData.actionDescriptors.filter(ad -> ad.name.toLowerCase() == actionName.toLowerCase());
		if (f.length == 0)
			return None;
		return Some(f[0]);
	}

	static function createFromDescriptor(actionDescriptor:ActionDescriptor) {
		var div:DivElement,
			nameSpan:SpanElement,
			valueInput:InputElement,
			possibleValuesSelect:SelectElement,
			booleanValueInput:InputElement;
		var divs:Array<DivElement> = [];
		for (prop in actionDescriptor.props) {
			div = cast Id.action_prop_tpl.get().cloneNode(true);
			div.classList.remove(Cls.hidden);
			div.id = prop.name;
			nameSpan = cast div.querySelector(Cls.prop_name.selector());
			valueInput = cast div.querySelector(Cls.prop_value.selector());
			possibleValuesSelect = cast div.querySelector(Cls.prop_possible_values.selector());
			booleanValueInput = cast div.querySelector(Cls.prop_bool_value.selector());
			if (prop.values != null && prop.values.length != 0) {
				possibleValuesSelect.classList.remove(Cls.hidden);
				Utils.fillSelectElement(possibleValuesSelect, [for (i in 0...prop.values.length) {value: i, text: prop.values[i]}]);
			} else {
				var notNullType = prop.type.replace('Null<', '');
				if (notNullType.startsWith("Bool")) {
					booleanValueInput.classList.remove(Cls.hidden);
				} else {
					if (notNullType.startsWith("Int") || notNullType.startsWith("UInt") || notNullType.startsWith("Float")) {
						valueInput.type = 'number';
					}
					valueInput.classList.remove(Cls.hidden);
				}
			}
			nameSpan.innerText = prop.name;
			var tooltipText = 'Property name : ${prop.name}\n';
			tooltipText += 'Type : ${prop.type}\n';
			tooltipText += 'Default value : ${prop.defaultValue}\n';
			tooltipText += 'Description : ${prop.description}\n';
			nameSpan.title = tooltipText;
			divs.push(div);
			Id.action_props.as(DivElement).appendChild(div);
		}
		return divs;
	}
}
