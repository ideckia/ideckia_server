package websocket;

class WebSocketConnection {
	var connectionJs:WebSocketConnectionJs;

	public function new(connectionJs:WebSocketConnectionJs) {
		this.connectionJs = connectionJs;
	}

	public function on(event:String, fb:Dynamic) {
		if (connectionJs == null)
			return;

		connectionJs.on(event, fb);
	}

	public function sendUTF(data:String) {
		if (connectionJs == null)
			return;

		connectionJs.sendUTF(data);
	}

	public function dispose() {
		connectionJs = null;
	}
}

@:jsRequire("websocket", "connection")
extern class WebSocketConnectionJs {
	public function on(event:String, fb:Dynamic):Void;
	public function sendUTF(data:String):Void;
}
