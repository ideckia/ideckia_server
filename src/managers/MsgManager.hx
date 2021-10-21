package managers;

import api.IdeckiaApi.ClientMsg;
import haxe.Json;
import websocket.WebSocketConnection;

class MsgManager {
	public static function route(connection:WebSocketConnection, rawMsg:Any) {
		var parsedMsg:ClientMsg = Json.parse(rawMsg);

		switch parsedMsg.whoami {
			case client:
				ClientManager.handleMsg(parsedMsg);
			case editor:
				EditorManager.handleMsg(connection, parsedMsg);
		}
	}

	public static function sendToAll(data:Any) {
		WebSocketConnection.sendToAll(Json.stringify(data));
	}

	public static function send(connection:WebSocketConnection, data:Any) {
		connection.sendUTF(Json.stringify(data));
	}
}
