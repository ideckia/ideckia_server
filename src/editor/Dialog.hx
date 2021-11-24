import hx.Selectors.Cls;
import js.html.Element;
import hx.Selectors.Id;
import Utils.Listener;

class Dialog {
	static var listeners:Array<Listener> = [];

	public static function show(title:String, content:Element, onAccept:Void->js.lib.Promise<Bool>, ?onCancel:Void->Void) {
		Id.dialog_title.get().textContent = title;
		Id.dialog_content.get().append(content);

		Utils.addListener(listeners, Id.cancel_dialog_btn.get(), 'click', (_) -> {
			close();
			if (onCancel != null)
				onCancel();
		});
		Utils.addListener(listeners, Id.accept_dialog_btn.get(), 'click', (_) -> {
			onAccept().then(doClose -> {
				if (doClose)
					close();
			}).catchError(error -> {
				trace('Dialog.onAccept error: $error');
				close();
			});
		});

		Id.modal_window.get().classList.remove(Cls.hidden);
	}

	public static function clear(delete:Bool = false) {
		if (Id.dialog_content.get().childElementCount == 0)
			return;

		if (delete) {
			Utils.clearElement(Id.dialog_content.get());
		} else {
			var content = Id.dialog_content.get().children[0];
			Id.templates.get().append(content);
		}
	}

	public static function close() {
		clear();
		Utils.removeListeners(listeners);
		Id.modal_window.get().classList.add(Cls.hidden);
	}
}
