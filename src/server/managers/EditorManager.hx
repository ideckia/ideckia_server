package managers;

import api.internal.ServerApi;
import websocket.WebSocketConnection;

using api.IdeckiaApi;
using StringTools;

class EditorManager {
	public static function handleMsg(connection:WebSocketConnection, msg:EditorMsg) {
		switch msg.type {
			case getEditorData:
				var layoutWithoutDynamicDir = {
					rows: LayoutManager.layout.rows,
					columns: LayoutManager.layout.columns,
					sharedVars: LayoutManager.layout.sharedVars,
					textSize: LayoutManager.layout.textSize,
					dirs: LayoutManager.layout.dirs.filter(d -> !d.name.toString().startsWith(LayoutManager.DYNAMIC_DIRECTORY_PREFIX)),
					fixedItems: LayoutManager.layout.fixedItems,
					icons: LayoutManager.layout.icons
				}
				var editorData:ServerMsg<EditorData> = {
					type: ServerMsgType.editorData,
					data: {
						layout: layoutWithoutDynamicDir,
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
