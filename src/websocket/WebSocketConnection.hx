package websocket;

@:jsRequire("websocket", "connection")
extern class WebSocketConnection {
	public static inline var CLOSE_REASON_NORMAL:UInt = 1000;
	public static inline var CLOSE_REASON_GOING_AWAY:UInt = 1001;
	public static inline var CLOSE_REASON_PROTOCOL_ERROR:UInt = 1002;
	public static inline var CLOSE_REASON_UNPROCESSABLE_INPUT:UInt = 1003;
	public static inline var CLOSE_REASON_RESERVED:UInt = 1004; // Reserved value.  Undefined meaning.
	public static inline var CLOSE_REASON_NOT_PROVIDED:UInt = 1005; // Not to be used on the wire
	public static inline var CLOSE_REASON_ABNORMAL:UInt = 1006; // Not to be used on the wire
	public static inline var CLOSE_REASON_INVALID_DATA:UInt = 1007;
	public static inline var CLOSE_REASON_POLICY_VIOLATION:UInt = 1008;
	public static inline var CLOSE_REASON_MESSAGE_TOO_BIG:UInt = 1009;
	public static inline var CLOSE_REASON_EXTENSION_REQUIRED:UInt = 1010;
	public function new(options:Dynamic);
	public function on(event:String, fb:Dynamic):Void;
	public function sendUTF(data:String):Void;
}
