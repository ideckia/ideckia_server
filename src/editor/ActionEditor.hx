import js.html.UListElement;
import api.IdeckiaApi;
import api.internal.ServerApi;
import hx.Selectors.Cls;
import hx.Selectors.Id;
import hx.Selectors.Tag;
import js.Browser.document;
import js.html.DivElement;
import js.html.Element;
import js.html.Event;
import js.html.InputElement;
import js.html.LIElement;
import js.html.SelectElement;
import js.html.SpanElement;

using StringTools;

class ActionEditor {
	static var editingAction:Action;
	static var changeListeners:Array<{element:Element, changeListener:Event->Void}> = [];
	static var listeners:Array<Utils.Listener> = [];

	public static function show(action:Action, parentState:ServerState) {
		var li = Utils.cloneElement(Id.action_list_item_tpl.get(), LIElement);
		switch Tag.span.firstFrom(li) {
			case Some(v):
				v.innerText = action.name;
			case None:
				trace('No [${Tag.span.selector()}] found in [${Id.action_list_item_tpl.selector()}]');
		}
		Utils.addListener(listeners, li, 'click', (event:Event) -> {
			event.stopImmediatePropagation();
			Utils.selectElement(li);
			edit(action);
		});

		switch Cls.delete_btn.firstFrom(li) {
			case Some(v):
				v.addEventListener('click', (event) -> {
					Utils.stopPropagation(event);
					if (js.Browser.window.confirm('Do you want to remove the action [${action.name}]?')) {
						parentState.actions.remove(action);
						App.dirtyData = true;
						DirEditor.refresh();
						ItemEditor.refresh();
					}
				});
			case None:
				trace('No [${Cls.delete_btn.selector()}] found in [${Id.action_list_item_tpl.selector()}]');
		}

		return li;
	}

	public static function refresh() {
		edit(editingAction);
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
					var propertyName = div.id;
					var valueInput:InputElement = cast div.querySelector(Cls.prop_value.selector());
					var possibleValuesSelect:SelectElement = cast div.querySelector(Cls.prop_possible_values.selector());
					var booleanValueInput:InputElement = cast div.querySelector(Cls.prop_bool_value.selector());
					var multiValuesDiv:DivElement = cast div.querySelector(Cls.prop_multi_values.selector());
					fieldValue = (Reflect.hasField(editingAction.props, propertyName)) ? Reflect.field(editingAction.props, propertyName) : '';
					var divDataType = div.dataset.prop_type;
					if (!valueInput.classList.contains(Cls.hidden)) {
						var isPrimitive = Utils.isPrimitiveTypeByName(divDataType);
						if (isPrimitive)
							valueInput.value = fieldValue;
						else
							valueInput.value = haxe.Json.stringify(fieldValue);

						Utils.addListener(listeners, valueInput, 'change', (_) -> {
							var value = valueInput.value;
							var propValue:Dynamic = (valueInput.type == 'number') ? Std.parseFloat(value) : (isPrimitive || value == '') ? value : haxe.Json.parse(value);
							Reflect.setField(editingAction.props, propertyName, propValue);
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
							Reflect.setField(editingAction.props, propertyName, children[possibleValuesSelect.selectedIndex].textContent);
							App.dirtyData = true;
						});
					} else if (!booleanValueInput.classList.contains(Cls.hidden)) {
						booleanValueInput.checked = Std.string(fieldValue) == 'true';
						Utils.addListener(listeners, booleanValueInput, 'change', (_) -> {
							Reflect.setField(editingAction.props, propertyName, booleanValueInput.checked);
							App.dirtyData = true;
						});
					} else if (!multiValuesDiv.classList.contains(Cls.hidden)) {
						var valuesArray:Array<Any> = cast fieldValue;
						switch Tag.ul.firstFrom(multiValuesDiv) {
							case Some(v):
								multiValuesDiv.removeChild(v);
							case None:
						}

						var ul = document.createUListElement();
						switch Cls.add_array_value.firstFrom(multiValuesDiv) {
							case Some(v):
								multiValuesDiv.insertBefore(ul, v);
							case None:
								multiValuesDiv.appendChild(ul);
						}
						var multiValuesType = multiValuesDiv.dataset.type;
						var isNumeric = Utils.isNumeric(multiValuesType);
						var isPrimitive = Utils.isPrimitiveTypeByName(multiValuesType);

						function updateValuesArray(ul:UListElement) {
							var newArray = [];
							for (ulChild in ul.children) {
								switch Tag.input.firstFrom(ulChild) {
									case Some(v):
										var value = cast(v, InputElement).value;
										var propValue:Dynamic = (isNumeric) ? Std.parseFloat(value) : (isPrimitive || value == '') ? value : haxe.Json.parse(value);
										newArray.push(propValue);
									case None:
								}
							}

							Reflect.setField(editingAction.props, propertyName, newArray);
							App.dirtyData = true;
						}

						inline function addArrayValue(value:Dynamic) {
							var li = Utils.cloneElement(Id.prop_multi_value_li_tpl.get(), LIElement);
							li.classList.remove(Cls.hidden);
							var liChild = document.createInputElement();
							if (isNumeric) {
								liChild.type = 'number';
							} else {
								liChild.type = 'text';
								liChild.setAttribute('list', Id.shared_vars_datalist);
							}

							if (value != null)
								liChild.value = (isPrimitive) ? value : haxe.Json.stringify(value);

							switch Cls.remove_value.firstFrom(li) {
								case Some(v):
									Utils.addListener(listeners, v, 'click', (_) -> {
										if (!js.Browser.window.confirm("Are you sure you want to remove the element?"))
											return;

										ul.removeChild(li);
										updateValuesArray(ul);
									});
								case None:
							}
							Utils.addListener(listeners, liChild, 'change', (e) -> {
								updateValuesArray(ul);
							});
							li.insertBefore(liChild, li.children[0]);
							ul.appendChild(li);
						}

						switch Cls.add_array_value.firstFrom(multiValuesDiv) {
							case Some(v):
								Utils.addListener(listeners, v, 'click', (_) -> addArrayValue(null));
							case None:
						}

						for (value in valuesArray) {
							addArrayValue(value);
						}
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
			booleanValueInput:InputElement,
			multiValuesDiv:DivElement;
		var divs:Array<DivElement> = [];
		for (prop in actionDescriptor.props) {
			if (prop.isShared) {
				var sharedName = actionDescriptor.name + '.' + prop.name;
				var found = false;
				for (sv in App.editorData.layout.sharedVars) {
					if (sv.key == sharedName) {
						found = true;
					}
				}

				if (!found) {
					App.updateSharedValues({
						key: sharedName,
						value: prop.defaultValue
					});
				}

				prop.defaultValue = sharedName;
				Reflect.setField(editingAction.props, prop.name, '$' + sharedName);
			}

			div = Utils.cloneElement(Id.action_prop_tpl.get(), DivElement);
			div.classList.remove(Cls.hidden);
			div.id = prop.name;
			var divDataType = prop.type.replace('Null<', '');
			div.dataset.prop_type = divDataType;
			nameSpan = cast div.querySelector(Cls.prop_name.selector());
			valueInput = cast div.querySelector(Cls.prop_value.selector());
			possibleValuesSelect = cast div.querySelector(Cls.prop_possible_values.selector());
			booleanValueInput = cast div.querySelector(Cls.prop_bool_value.selector());
			multiValuesDiv = cast div.querySelector(Cls.prop_multi_values.selector());
			if (prop.values != null && prop.values.length != 0) {
				possibleValuesSelect.classList.remove(Cls.hidden);
				Utils.fillSelectElement(possibleValuesSelect, [for (i in 0...prop.values.length) {value: i, text: prop.values[i]}]);
			} else {
				if (divDataType.startsWith("Bool")) {
					booleanValueInput.classList.remove(Cls.hidden);
				} else if (divDataType.startsWith('Array')) {
					multiValuesDiv.dataset.type = divDataType.replace('Array<', '');
					multiValuesDiv.classList.remove(Cls.hidden);
				} else {
					if (divDataType.startsWith("Int") || divDataType.startsWith("UInt") || divDataType.startsWith("Float")) {
						valueInput.type = 'number';
					} else {
						valueInput.setAttribute('list', Id.shared_vars_datalist);
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
