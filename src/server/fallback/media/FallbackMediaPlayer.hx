package fallback.media;

import api.media.IMediaPlayer;

@:keep
class FallbackMediaPlayer implements IMediaPlayer {
	var ids:Array<Int> = [];

	public function new() {}

	public function play(path:String, loop:Bool = false, ?onEnd:Void->Void) {
		if (haxe.io.Path.extension(path) != 'wav')
			throw new haxe.Exception('FallbackMediaPlayer only can play WAV files.');

		var childProcess;
		switch Sys.systemName() {
			case 'Windows':
				childProcess = js.node.ChildProcess.spawn('powershell', ['-c', '(New-Object System.Media.SoundPlayer "' + path + '").PlaySync();']);
				childProcess.stdin.end();
			case 'Mac':
				childProcess = js.node.ChildProcess.spawn('afplay', [path]);
			case 'Linux':
				childProcess = js.node.ChildProcess.spawn('aplay', [path]);
			case x:
				throw new haxe.Exception('The wav file [$path] can not be played on [$x] platform.');
		}

		childProcess.on('error', err -> {
			throw new haxe.Exception('Failed to play the wav file [$path] [$err]');
		});

		childProcess.on('close', (code) -> {
			if (code == 0) {
				if (onEnd != null)
					onEnd();
				if (loop)
					play(path, loop);
			} else {
				throw new haxe.Exception('Failed to play the wav file [$path] [code=$code]');
			}
		});

		var processId = childProcess.pid;
		ids.push(processId);

		return processId;
	}

	public function pause(id:Int) {}

	public function stop(id:Int) {
		if (!ids.contains(id))
			return;

		if (Sys.systemName() == "Windows") {
			js.node.ChildProcess.exec('taskkill /PID ${id} /T /F', (error, _, _) -> {});
		} else {
			// see https://nodejs.org/api/child_process.html#child_process_options_detached
			// If pid is less than -1, then sig is sent to every process in the process group whose ID is -pid.
			js.Node.process.kill(-id, 'SIGKILL');
		}

		ids.remove(id);
	}
}
