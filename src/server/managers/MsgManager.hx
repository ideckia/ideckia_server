package managers;

import api.IdeckiaApi;
import api.IdeckiaApi.ClientMsg;
import haxe.Json;
import websocket.WebSocketConnection;

class MsgManager {
	public static function route(connection:WebSocketConnection, rawMsg:Any) {
		var parsedMsg:{whoami:Caller} = Json.parse(rawMsg);
		switch parsedMsg.whoami {
			case client:
				ClientManager.handleMsg(Json.parse(rawMsg));
			case editor:
				EditorManager.handleMsg(connection, tink.Json.parse(Std.string(rawMsg)));
		}
	}

	public static function sendToAll(data:Any) {
		WebSocketConnection.sendToAll(Json.stringify(data));
	}

	public static function send(connection:WebSocketConnection, data:Any) {
		connection.send(Json.stringify(data));
	}
}
