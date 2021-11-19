import hx.Selectors.Cls;
import js.html.Element;
import hx.Selectors.Id;
import Utils.Listener;

class Dialog {
	static var listeners:Array<Listener> = [];

	public static function show(title:String, content:Element, onAccept:Void->Bool, ?onCancel:Void->Void) {
		Id.dialog_title.get().textContent = title;
		Id.dialog_content.get().append(content);

		Utils.addListener(listeners, Id.cancel_dialog_btn.get(), 'click', (_) -> {
			close(content);
			if (onCancel != null)
				onCancel();
		});
		Utils.addListener(listeners, Id.accept_dialog_btn.get(), 'click', (_) -> {
			if (onAccept()) {
				close(content);
			}
		});

		Id.modal_window.get().classList.remove(Cls.hidden);
	}

	public static function close(content:Element) {
		Id.templates.get().append(content);
		Utils.removeListeners(listeners);
		Id.modal_window.get().classList.add(Cls.hidden);
	}
}
