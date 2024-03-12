import api.IdeckiaApi.ActionDescriptor;
import hx.Selectors.Tag;
import js.Browser.document;
import js.html.InputElement;
import js.html.LabelElement;
import js.html.Element;

class PresetEditor {
	public static function edit(actionName:String, preset:{name:String, props:Any}):js.lib.Promise<Any> {
		return new js.lib.Promise((resolvePreset, _) -> {
			var presetString = haxe.Json.stringify(preset.props);
			var ereg = ~/"([\w-]+)":"::([\w\s-:.]+)::"/;
			var fieldName;
			var fieldValueTpl;
			var editableFields:Map<String, String> = new Map();

			while (ereg.match(presetString)) {
				fieldName = ereg.matched(1);
				fieldValueTpl = ereg.matched(2);
				editableFields.set(fieldName, fieldValueTpl);
				presetString = ereg.matchedRight();
			}

			if (Lambda.empty(editableFields))
				return resolvePreset(preset.props);

			var descriptor = null;
			switch App.getActionDescriptorByName(actionName) {
				case Some(v):
					descriptor = v;
				case None:
			};
			var container:Element = document.createDivElement();
			var div, sharedTextDiv;
			var isAnyShared:Bool = false;
			var label:LabelElement;
			var input:InputElement;
			var i = 0;
			for (key => value in editableFields) {
				div = document.createDivElement();
				input = document.createInputElement();
				input.dataset.tpl = '::$value::';
				input.id = key + i;
				input.classList.add(key);
				label = document.createLabelElement();
				label.textContent = key;
				label.htmlFor = input.id;

				div.appendChild(label);

				input.value = if (isShared(key, descriptor)) {
					input.disabled = true;
					sharedTextDiv = document.createDivElement();
					sharedTextDiv.textContent = '::text_content_shared_variable::';
					div.appendChild(sharedTextDiv);
					isAnyShared = true;

					"$" + descriptor.name + "." + key;
				} else {
					value;
				}

				div.appendChild(input);
				container.appendChild(div);
				i++;
			}

			if (isAnyShared) {
				div = document.createDivElement();
				div.textContent = '::text_content_edit_shared_hint::';
				container.appendChild(div);
			}

			Dialog.clear();

			Dialog.show(Utils.formatString('::show_title_action_preset_editor::', [actionName, preset.name]), container, () -> {
				return new js.lib.Promise((resolveDialog, _) -> {
					var inputs = Tag.input.from(container);
					var fieldValue;
					presetString = haxe.Json.stringify(preset.props);
					for (i in inputs) {
						input = cast i;
						fieldName = input.className;
						fieldValue = input.value;

						fieldValueTpl = input.dataset.tpl;
						if (fieldValue != null && StringTools.trim(fieldValue) != '') {
							presetString = StringTools.replace(presetString, fieldValueTpl, fieldValue);
						}
					}

					Dialog.clear(true);

					resolvePreset(haxe.Json.parse(presetString));
					resolveDialog(true);
				});
			});
		});
	}

	static function isShared(fieldName:String, descriptor:ActionDescriptor) {
		if (descriptor == null)
			return false;

		for (prop in descriptor.props) {
			if (!prop.isShared)
				continue;
			if (prop.name == fieldName) {
				return true;
			}
		}

		return false;
	}
}
