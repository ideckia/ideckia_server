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
	static var editingAction:Action;
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
				Utils.clearElement(Id.action_props.get());
				editingAction = action;
				var fieldValue;
				Id.action_title.get().textContent = '[${actionDescriptor.name}] action properties';
				Id.action_description.get().textContent = actionDescriptor.description;
				Id.action_properties.get().classList.remove(Cls.hidden);
				for (div in createFromDescriptor(actionDescriptor)) {
					var valueInput:InputElement = cast div.querySelector(Cls.prop_value.selector());
					var possibleValuesSelect:SelectElement = cast div.querySelector(Cls.prop_possible_values.selector());
					var booleanValueInput:InputElement = cast div.querySelector(Cls.prop_bool_value.selector());
					fieldValue = (Reflect.hasField(editingAction.props, div.id)) ? Reflect.field(editingAction.props, div.id) : '';
					if (!valueInput.classList.contains(Cls.hidden)) {
						var notNullType = div.dataset.prop_type.replace('Null<', '');
						var isPrimitive = notNullType.startsWith("Int") || notNullType.startsWith("UInt") || notNullType.startsWith("Float")
							|| notNullType.startsWith("String");
						if (isPrimitive)
							valueInput.value = fieldValue;
						else
							valueInput.value = haxe.Json.stringify(fieldValue);

						Utils.addListener(listeners, valueInput, 'change', (_) -> {
							var value = valueInput.value;
							var propValue:Dynamic = (valueInput.type == 'number') ? Std.parseFloat(value) : (isPrimitive || value == '') ? value : haxe.Json.parse(value);
							Reflect.setField(editingAction.props, div.id, propValue);
							App.dirtyData = true;
						});
					} else if (!possibleValuesSelect.classList.contains(Cls.hidden)) {
						var children = possibleValuesSelect.children;
						for (cind in 0...children.length) {
							if (children.item(cind).textContent == fieldValue) {
								possibleValuesSelect.selectedIndex = cind;
							}
						}

						Utils.addListener(listeners, possibleValuesSelect, 'change', (_) -> {
							Reflect.setField(editingAction.props, div.id, children[possibleValuesSelect.selectedIndex].textContent);
							App.dirtyData = true;
						});
					} else {
						booleanValueInput.checked = Std.string(fieldValue) == 'true';
						Utils.addListener(listeners, booleanValueInput, 'change', (_) -> {
							Reflect.setField(editingAction.props, div.id, booleanValueInput.checked);
							App.dirtyData = true;
						});
					}

					Id.action_props.get().appendChild(div);
				}
		}
	}

	public static function hide() {
		editingAction = null;
		Utils.removeListeners(listeners);
		Id.action_properties.get().classList.add(Cls.hidden);
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
			div.dataset.prop_type = prop.type;
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
