package managers;

using api.IdeckiaCmdApi;

import websocket.WebSocketConnection;

class EditorManager {
	static var wsConnection:WebSocketConnection;

	public static function handleMsg(connection:WebSocketConnection, msg:ClientMsg) {
		if (wsConnection == null)
			wsConnection = connection;

		switch msg.type {
			case getCommands:
				MsgManager.send(connection, CmdManager.getEditorCmdDescriptors());
			case t:
				throw new haxe.Exception('[$t] type of message is not allowed for the client.');
		}
	}
}
