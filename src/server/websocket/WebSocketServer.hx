package websocket;

import websocket.WebSocketConnection.WebSocketConnectionJs;
import js.node.Os;

using StringTools;

class WebSocketServer {
	public static inline var DISCOVER_ENDPOINT = '/ping';
	public static inline var EDITOR_ENDPOINT = '/editor';

	@:v('ideckia.port:8888')
	static var port:Int;

	var ws:WebSocketServerJs;

	public function new() {
		var server = js.node.Http.createServer(function(request, response) {
			var headers = {
				'Access-Control-Allow-Origin': '*',
				'Access-Control-Allow-Methods': 'OPTIONS, POST, GET',
				'Access-Control-Max-Age': 2592000, // 30 days
				"Access-Control-Allow-Headers": "Content-Type",
				"Content-Type": "text/html",
				/** add other headers as per requirement */
			};

			if (request.method == 'OPTIONS') {
				response.writeHead(204, headers);
				response.end();
				return;
			}

			if (['GET', 'POST'].indexOf(request.method) > -1) {
				var code = 404;
				var body = null;
				if (request.url.indexOf(DISCOVER_ENDPOINT) != -1) {
					code = 200;
					body = haxe.Json.stringify({pong: Os.hostname()});
				} else if (request.url.indexOf(EDITOR_ENDPOINT) != -1 || request.url.endsWith('.js') || request.url.endsWith('.css')) {
					code = 200;
					var relativePath = '/${EDITOR_ENDPOINT}';
					if (request.url.endsWith(EDITOR_ENDPOINT)) {
						relativePath += '/index.html';
					} else {
						relativePath += '/${request.url}';
					}
					var absolutePath = '${Ideckia.getAppPath()}/$relativePath';
					if (!sys.FileSystem.exists(absolutePath)) {
						absolutePath = js.Node.__dirname + '$relativePath';
					}
					headers = {"Content-Type": "text/" + haxe.io.Path.extension(absolutePath)};
					body = sys.io.File.getContent(absolutePath);
				}

				response.writeHead(code, headers);
				response.end(body);
				return;
			}

			response.writeHead(405, headers);
			response.end('${request.method} is not allowed for the request.');
		});

		server.listen(port, () -> {
			var banner = haxe.Resource.getString('banner');
			banner = banner.replace('::version::', Ideckia.CURRENT_VERSION);
			banner = banner.replace('::buildDate::', Macros.buildDate().toString());
			banner = banner.replace('::address::', '${getIPAddress()}:$port');
			js.Node.console.log(banner);
		});

		ws = new WebSocketServerJs({
			server: server
		});

		ws.on('connection', function(connectionjs:WebSocketConnectionJs) {
			Log.info('Connection request received');
			var connection = new WebSocketConnection(connectionjs);
			onConnect(connection);

			connection.on('message', function(msg:Any) {
				onMessage(connection, msg);
			});

			connection.on('close', function(reasonCode, description) {
				onClose(connection, reasonCode, description);
			});
		});
	}

	public dynamic function onConnect(connection:WebSocketConnection):Void {}

	public dynamic function onMessage(connection:WebSocketConnection, msg:Any):Void {}

	public dynamic function onClose(connection:WebSocketConnection, reasonCode:Int, description:String):Void {}

	function getIPAddress() {
		var interfaces = Os.networkInterfaces();
		for (iface in interfaces) {
			for (alias in iface) {
				if (alias.family == 'IPv4' && alias.address.startsWith('192'))
					return alias.address;
			}
		}
		return '0.0.0.0';
	}
}

@:jsRequire("ws", "WebSocketServer")
extern class WebSocketServerJs {
	public function new(options:Dynamic);
	public function on(event:String, fb:Dynamic):Void;
}
