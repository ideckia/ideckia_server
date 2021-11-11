import hx.Selectors.Cls;
import hx.Selectors.Id;
import js.html.Event;
import js.html.OptionElement;
import js.html.SelectElement;
import js.html.Element;

class Utils {
	public static inline function clearElement(e:Element) {
		while (e.hasChildNodes())
			e.removeChild(e.firstChild);
	}

	public static inline function selectElement(e:Element) {
		for (s in Cls.selected.get())
			s.classList.remove(Cls.selected);

		e.classList.add(Cls.selected);
	}

	public static function hideProps() {
		ItemEdit.hide();
		StateEdit.hide();
		ActionEdit.hide();
	}

	public static function fillSelectElement(select:SelectElement, optionsArray:Array<{value:Int, text:String}>, ?onChange:Event->Void) {
		clearElement(select);

		var option:OptionElement;
		for (opt in optionsArray) {
			option = js.Browser.document.createOptionElement();
			option.value = Std.string(opt.value);
			option.text = opt.text;
			select.add(option);
		}

		if (onChange != null) {
			select.addEventListener('change', onChange);
		}
	}
}
