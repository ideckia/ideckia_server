import hx.Selectors.Tag;
import js.Browser.document;
import js.html.InputElement;
import js.html.LabelElement;
import js.html.Element;

class PresetEdit {
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

			var container:Element = document.createDivElement();
			var label:LabelElement;
			var input:InputElement;
			var i = 0;
			for (key => value in editableFields) {
				input = document.createInputElement();
				input.value = value;
				input.dataset.tpl = '::$value::';
				input.id = key + i;
				input.classList.add(key);
				label = document.createLabelElement();
				label.textContent = key;
				label.htmlFor = input.id;
				container.appendChild(label);
				container.appendChild(input);
				i++;
			}

			Dialog.clear();

			Dialog.show('Edit [$actionName.${preset.name}] preset', container, () -> {
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
}
