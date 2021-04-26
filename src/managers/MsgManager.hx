package managers;

import api.IdeckiaCmdApi.ClientMsg;
import haxe.Json;
import websocket.WebSocketConnection;

class MsgManager {
	public static function route(connection:WebSocketConnection, rawMsg:Any) {
		var parsedMsg:ClientMsg = Json.parse(rawMsg);

		switch parsedMsg.whoami {
			case client:
				ClientManager.handleMsg(connection, parsedMsg);
			case editor:
				EditorManager.handleMsg(connection, parsedMsg);
		}
	}

	public static function send(connection:WebSocketConnection, data:Any) {
		connection.sendUTF(Json.stringify(data));
	}
}
