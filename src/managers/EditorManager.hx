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
				var descriptorsData:ServerMsg<Array<ActionDescriptor>> = {
					type: ServerMsgType.actionDescriptors,
					data: ActionManager.getEditorActionDescriptors()
				};
				MsgManager.send(connection, descriptorsData);
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
