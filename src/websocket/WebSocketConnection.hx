package websocket;

@:jsRequire("websocket", "connection")
extern class WebSocketConnection {
	public function new(options:Dynamic);
	public function on(event:String, fb:Dynamic):Void;
	public function sendUTF(data:String):Void;
}
