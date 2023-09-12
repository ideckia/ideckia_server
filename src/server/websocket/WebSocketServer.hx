package websocket;

import api.internal.ServerApi.StateId;
import api.internal.ServerApi.ActionId;
import managers.ActionManager;
import managers.LayoutManager;
import websocket.WebSocketConnection.WebSocketConnectionJs;
import api.IdeckiaApi.Endpoint;
import js.node.Os;

using StringTools;

class WebSocketServer {
	public static var ACTION_ID_DESCRIPTOR = ~/\/action\/([0-9]+)\/descriptor/;
	public static var STATE_ID_ACTIONS_STATUS = ~/\/state\/([0-9]+)\/actions\/status/;

	@:v('ideckia.port:8888')
	static public var port:Int;

	var ws:WebSocketServerJs;

	public function new() {
		var server = js.node.Http.createServer(function(request, response) {
			handleRequest(request).then(res -> {
				response.writeHead(res.code, res.headers);
				response.end(res.body);
			});
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

	function handleRequest(request:js.node.http.IncomingMessage):js.lib.Promise<{code:Int, headers:Any, body:String}> {
		return new js.lib.Promise((resolve, reject) -> {
			var headers = {
				'Access-Control-Allow-Origin': '*',
				'Access-Control-Allow-Methods': 'OPTIONS, POST, GET',
				'Access-Control-Max-Age': 2592000, // 30 days
				"Access-Control-Allow-Headers": "Content-Type",
				"Content-Type": "text/html",
			};

			if (request.method == 'OPTIONS') {
				resolve({
					code: 204,
					headers: headers,
					body: null
				});
			} else if (['GET', 'POST'].indexOf(request.method) > -1) {
				var requestUrl = request.url;
				Log.debug('${request.method} - $requestUrl');
				if (requestUrl == pingEndpoint) {
					resolve({
						code: 200,
						headers: headers,
						body: haxe.Json.stringify({pong: Os.hostname()})
					});
				} else if (requestUrl.indexOf(editorEndpoint) != -1 || requestUrl.endsWith('.js') || requestUrl.endsWith('.css')) {
					var relativePath = '/${editorEndpoint}';
					if (requestUrl.endsWith(editorEndpoint)) {
						relativePath += '/index.html';
					} else {
						relativePath += '/${requestUrl}';
					}
					var absolutePath = Ideckia.getAppPath(relativePath);
					if (!sys.FileSystem.exists(absolutePath) && Ideckia.isPkg()) {
						absolutePath = js.Node.__dirname + '$relativePath';
					}
					headers = {"Content-Type": "text/" + haxe.io.Path.extension(absolutePath)};
					resolve({
						code: 200,
						headers: headers,
						body: sys.io.File.getContent(absolutePath)
					});
				} else if (request.method == 'POST' && requestUrl == newActionEndpoint) {
					var data = '';
					request.on('data', chunck -> {
						data += chunck;
					});
					request.on('end', chunck -> {
						Log.debug('Create new Action received: $data');
						var newActionPath = Ideckia.createNewAction(haxe.Json.parse(data));
						resolve({
							code: 200,
							headers: headers,
							body: newActionPath
						});
					});
				} else if (request.method == 'GET' && requestUrl == actionTemplatesEndpoint) {
					resolve({
						code: 200,
						headers: headers,
						body: haxe.Json.stringify(ActionManager.getActionTemplates())
					});
				} else if (request.method == 'GET' && requestUrl.startsWith('/action')) {
					if (ACTION_ID_DESCRIPTOR.match(requestUrl)) {
						var id = Std.parseInt(ACTION_ID_DESCRIPTOR.matched(1));
						var body = switch ActionManager.getActionDescriptorById(new ActionId(id)) {
							case Some(v): v;
							case None: {};
						};

						resolve({
							code: 200,
							headers: headers,
							body: haxe.Json.stringify(body)
						});
					} else {
						resolve({
							code: 404,
							headers: headers,
							body: 'Endpoint not matching'
						});
					}
				} else if (request.method == 'GET' && requestUrl.startsWith('/state')) {
					if (STATE_ID_ACTIONS_STATUS.match(requestUrl)) {
						var id = Std.parseInt(STATE_ID_ACTIONS_STATUS.matched(1));
						ActionManager.getActionsStatusesByStateId(new StateId(id)).then(statuses -> resolve({
							code: 200,
							headers: headers,
							body: haxe.Json.stringify(statuses)
						})).catchError(e -> {
							Log.error(e);
							resolve({
								code: 500,
								headers: headers,
								body: 'Error getting statuses of the actions from the state [$id]: $e'
							});
						});
					} else {
						resolve({
							code: 404,
							headers: headers,
							body: 'Endpoint not matching'
						});
					}
				} else if (request.method == 'POST' && requestUrl == layoutAppendEndpoint) {
					var data = '';
					request.on('data', chunck -> {
						data += chunck;
					});
					request.on('end', chunck -> {
						LayoutManager.appendLayout(tink.Json.parse(data));
						sys.io.File.saveContent(LayoutManager.getLayoutPath(), LayoutManager.exportLayout());
						resolve({
							code: 200,
							headers: headers,
							body: data
						});
					});
				} else if (request.method == 'POST' && requestUrl == directoryExportEndpoint) {
					var data = '';
					request.on('data', chunck -> {
						data += chunck;
					});
					request.on('end', chunck -> {
						Log.debug('Export directories received: $data');
						var dirNames:Array<String> = haxe.Json.parse(data);
						switch LayoutManager.exportDirs(dirNames) {
							case Some(exported):
								Log.info('[${exported.processedDirNames.join(',')}] successfully exported.');
								resolve({
									code: 200,
									headers: headers,
									body: haxe.Json.stringify(exported.layout)
								});
							case None:
								Log.info('Could not find [$dirNames] directories in the layout file.');
								resolve({
									code: 404,
									headers: headers,
									body: 'Could not find [$dirNames] directories in the layout file.'
								});
						};
					});
				} else {
					resolve({
						code: 404,
						headers: headers,
						body: null
					});
				}
			} else {
				resolve({
					code: 405,
					headers: headers,
					body: '${request.method} is not allowed for the request.'
				});
			}
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
