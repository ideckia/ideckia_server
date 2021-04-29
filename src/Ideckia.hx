package;

import js.node.Os;
import managers.LayoutManager;
import managers.MsgManager;
using StringTools;
import websocket.*;

@:build(appropos.Appropos.generate())
class Ideckia {

	public static inline var DISCOVER_ENDPOINT = '/marco';
	public static inline var DISCOVER_RESPONSE = 'polo';
	public static inline var NAME_ENDPOINT = '/name';

	@:v('ideckia.port:8000')
	static var port:Int;

	@:v('ideckia.log-level:ERROR')
	static var logLevel:String;
	
	@:v('ideckia.auto-launch-enabled:true')
	static var autoLaunchEnabled:Bool;
	
	@:v('ideckia.actions-path:actions')
	static var actionsPath:String;
    
    function new() {
		
		Log.level = logLevel;
		
		var autoLauncher = new AutoLaunch({
			name: 'Ideckia',
			path: sys.FileSystem.fullPath(Sys.programPath())
		});
		
		autoLauncher.isEnabled()
			.then((isEnabled) -> {
				switch [isEnabled, autoLaunchEnabled] {
					case [false, false] | [true, true]:
						return;
					case [false, true]:
						Log.info('Enabling auto-launch.');
						autoLauncher.enable();
					case [true, false]:
						Log.info('Disabling auto-launch.');
						autoLauncher.disable();
				}
			})
			.catchError((error) -> {
				Log.error('Error with AutoLaunch: $error');
			});
		
		if (Sys.args().indexOf('--create-action') != -1) {
			api.action.creator.ActionCreator.create(actionsPath);
			return;
		}
		
		var server = js.node.Http.createServer(function(request, response) {
			final headers = {
				'Access-Control-Allow-Origin': '*',
				'Access-Control-Allow-Methods': 'OPTIONS, POST, GET',
				'Access-Control-Max-Age': 2592000, // 30 days
				"Access-Control-Allow-Headers": "Content-Type",
				"Content-Type": "text/plain",
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
					body = DISCOVER_RESPONSE;
				} else if (request.url.indexOf(NAME_ENDPOINT) != -1) {
					code = 200;
					body = Os.hostname();
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
			banner = banner.replace('::buildDate::', Macros.buildDate().toString());
			banner = banner.replace('::gitCommitHash::', Macros.getGitCommitHash());
			banner = banner.replace('::port::', '$port');
			js.Node.console.log(banner);
		});
		
		// create the server
		var wsServer = new WebSocketServer({
			httpServer: server
		});
		
		LayoutManager.load();
		// WebSocket server
		wsServer.on('request', function(request) {

			var connection = request.accept(null, request.origin);
			
			MsgManager.send(connection, LayoutManager.currentFolderForClient());

			// This is the most important callback for us, we'll handle
			// all messages from users here.
			connection.on('message', function(msg:{type:String, utf8Data:String}) {
				Log.debug('onMessage: $msg');
				if (msg.type == 'utf8') {
					MsgManager.route(connection, msg.utf8Data);
				}
			});

			connection.on('close', function(connection) {
				Log.debug('onClose');
			});
		});
	}

	static function main() {
		appropos.Appropos.init(Sys.getCwd() + '/app.props');
		new Ideckia();
	}
}