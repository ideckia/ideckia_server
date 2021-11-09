package managers;

import api.internal.ServerApi;

using api.IdeckiaApi;

import websocket.WebSocketConnection;

class EditorManager {
	public static function handleMsg(connection:WebSocketConnection, msg:ClientMsg) {
		switch msg.type {
			case getEditorData:
				var editorData:ServerMsg<EditorData> = {
					type: ServerMsgType.editorData,
					data: {
						layout: LayoutManager.layout,
						actionDescriptors: ActionManager.getEditorActionDescriptors()
					}
				};
				MsgManager.send(connection, editorData);
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
