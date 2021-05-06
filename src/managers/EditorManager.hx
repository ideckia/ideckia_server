package managers;

using api.IdeckiaApi;

import websocket.WebSocketConnection;

class EditorManager {
	static var wsConnection:WebSocketConnection;

	public static function handleMsg(connection:WebSocketConnection, msg:ClientMsg) {
		wsConnection = connection;

		switch msg.type {
			case getActions:
				MsgManager.send(connection, ActionManager.getEditorActionDescriptors());
			case t:
				throw new haxe.Exception('[$t] type of message is not allowed for the client.');
		}
	}
}
