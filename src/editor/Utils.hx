import api.internal.ServerApi;
import hx.Selectors.Cls;
import js.html.Element;
import js.html.Event;
import js.html.OptionElement;
import js.html.SelectElement;
import haxe.ds.Option;

typedef Listener = {
	var element:Element;
	var type:String;
	var callback:Event->Void;
}

class Utils {
	static var lastItemId:UInt = 0;
	static var lastStateId:UInt = 0;

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

	public static function addListener(listeners:Array<Listener>, e:Element, t:String, cb:Event->Void, once:Bool = false) {
		e.addEventListener(t, cb, {once: once});
		listeners.push({
			element: e,
			type: t,
			callback: cb
		});
	}

	public static function removeListeners(listeners:Array<Listener>) {
		for (l in listeners)
			l.element.removeEventListener(l.type, l.callback);
		listeners = [];
	}

	public static function createNewState():ServerState {
		return {
			id: getNextStateId()
		};
	}

	public static function createNewItem() {
		var changeDirType = 'changedir';
		var statesType = 'states';
		var itemType = js.Browser.window.prompt('What type of item do you want to create?\n-$changeDirType\n-$statesType');

		if (itemType == null)
			return None;

		if (itemType != changeDirType && itemType != statesType) {
			js.Browser.window.alert('$itemType is not a correct item type.');
			return None;
		}

		var state = createNewState();

		var item:ServerItem = {
			id: Utils.getNextItemId(),
			kind: if (itemType == changeDirType) {
				ChangeDir(App.editorData.layout.dirs[0].name, state);
			} else {
				States(0, [state]);
			}
		}

		return Some(item);
	}

	public static function getNextItemId() {
		if (lastItemId == 0) {
			for (d in App.editorData.layout.dirs) {
				for (i in d.items) {
					if (i.id.toUInt() > lastItemId)
						lastItemId = i.id.toUInt();
				}
			}
		}

		return new ItemId(lastItemId++);
	}

	public static function getNextStateId() {
		if (lastStateId == 0) {
			for (d in App.editorData.layout.dirs) {
				for (i in d.items) {
					switch i.kind {
						case null:
						case ChangeDir(_, state):
							if (state.id.toUInt() > lastStateId)
								lastStateId = state.id.toUInt();
						case States(_, list):
							for (s in list)
								if (s.id.toUInt() > lastStateId)
									lastStateId = s.id.toUInt();
					}
				}
			}
		}

		return new StateId(lastStateId++);
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
