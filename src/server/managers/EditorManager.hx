package managers;

import api.internal.ServerApi;

using api.IdeckiaApi;

import websocket.WebSocketConnection;

class EditorManager {
	public static function handleMsg(connection:WebSocketConnection, msg:EditorMsg) {
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
			case saveLayout:
				var layoutContent = LayoutManager.exportLayout(msg.layout);
				sys.io.File.saveContent(LayoutManager.getLayoutPath(), layoutContent);
			case t:
				throw new haxe.Exception('[$t] type of message is not allowed for the editor.');
		}
	}
}
