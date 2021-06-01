package managers;

import api.internal.ServerApi.ServerItem;
import api.internal.ServerApi.ItemId;
using api.IdeckiaApi;

import websocket.WebSocketConnection;

class EditorManager {
	static var wsConnection:WebSocketConnection;

	public static function handleMsg(connection:WebSocketConnection, msg:ClientMsg) {
		wsConnection = connection;

		switch msg.type {
			case getActions:
				MsgManager.send(connection, ActionManager.getEditorActionDescriptors());
			case getServerItem:
				var data:ServerMsg<ServerItem> = {
					type: ServerMsgType.serverItem,
					data: LayoutManager.getItem(new ItemId(msg.itemId))
				};
				MsgManager.send(connection, data);
			case t:
				throw new haxe.Exception('[$t] type of message is not allowed for the editor.');
		}
	}
}
