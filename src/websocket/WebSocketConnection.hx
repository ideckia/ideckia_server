package websocket;

class WebSocketConnection {
	var connectionJs:WebSocketConnectionJs;

	static var ALL:Array<WebSocketConnection> = [];

	public function new(connectionJs:WebSocketConnectionJs) {
		this.connectionJs = connectionJs;
		ALL.push(this);
	}

	public function on(event:String, fb:Dynamic) {
		if (connectionJs == null)
			return;

		connectionJs.on(event, fb);
	}

	public function send(data:String) {
		if (connectionJs == null)
			return;

		connectionJs.send(data);
	}

	public static function sendToAll(data:String) {
		for (c in ALL)
			c.send(data);
	}

	public function dispose() {
		connectionJs = null;
		ALL.remove(this);
	}
}

@:jsRequire("ws", "websocket")
extern class WebSocketConnectionJs {
	public function on(event:String, fb:Dynamic):Void;
	public function send(data:String):Void;
	public function terminate():Void;
}
