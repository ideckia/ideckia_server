package managers;

import haxe.io.Path;
import tink.http.Client.fetch;
import tink.semver.Version;

using StringTools;

typedef Info = {
	var repository:String;
	var filename:String;
	var version:String;
}

typedef GhRelease = {
	var tag_name:String;
	var assets:Array<{
		id:String,
		url:String,
		browser_download_url:String,
		name:String
	}>;
	var version:String;
}

class UpdateManager {
	static var checked:Array<String> = [];

	public static function checkUpdates(path:String, moduleName:String) {
		if (checked.contains(moduleName))
			return;
		checked.push(moduleName);
		var infoPath = Path.join([path, moduleName, '.info']);
		if (!sys.FileSystem.exists(infoPath))
			return;

		Log.debug('Checking updates for [$moduleName]');
		var content = try sys.io.File.getContent(infoPath) catch (e) '';
		var info:Info = haxe.Json.parse(content);

		if (info.repository == null || info.filename == null || info.version == null)
			return;

		var githubEreg = ~/github.com\/([\w-\.]*)\/([\w-\.]*)/;

		if (githubEreg.match(info.repository)) {
			var owner = githubEreg.matched(1);
			var repo = githubEreg.matched(2);
			checkActionGithubRelease(path, moduleName, info, owner, repo);
		}
	}

	public static function checkServerRelease() {
		if (Ideckia.CURRENT_VERSION.indexOf(Macros.DEV_COMMIT_PREFIX) != -1)
			return;
		var ext = switch Sys.systemName() {
			case "Linux": 'linux';
			case "Mac": 'macos';
			case "Windows": 'win.exe';
			case _: '';
		};
		var filename = 'ideckia-$ext';
		checkGithubRemoteVersion('ideckia_server', filename, extractSemVer(Ideckia.CURRENT_VERSION), 'ideckia', 'ideckia_server').then(downloadUrl -> {
			downloadRemoteAsset('ideckia_server', downloadUrl).then(bytes -> {
				try {
					var updateDir = Ideckia.getAppPath('server_update');
					if (!sys.FileSystem.exists(updateDir))
						sys.FileSystem.createDirectory(updateDir);
					var savePath = haxe.io.Path.join([updateDir, filename]);
					sys.io.File.saveBytes(savePath, bytes);
					Ideckia.dialog.info('New version of ideckia_server downloaded', 'Please quit Ideckia and override the executable with [$savePath].');
				} catch (e:haxe.Exception) {
					var msg = 'Error saving [ideckia_server] update: ${e.message}';
					Ideckia.dialog.error('Error when updating', msg);
					Log.error(msg);
					Log.raw(e);
				}
			});
		});
	}

	static function checkActionGithubRelease(path:String, moduleName:String, info:Info, owner:String, repo:String) {
		checkGithubRemoteVersion(moduleName, info.filename, extractSemVer(info.version), owner, repo).then(downloadUrl -> {
			downloadRemoteAsset(moduleName, downloadUrl).then(bytes -> {
				try {
					unzip(bytes, path);
				} catch (e:haxe.Exception) {
					var msg = 'Error unzipping [$moduleName] update: ${e.message}';
					Ideckia.dialog.error('Error when updating', msg);
					Log.error(e);
				}
			});
		});
	}

	static function checkGithubRemoteVersion(moduleName:String, filename:String, currentVersion:Version, owner:String, repo:String):js.lib.Promise<String> {
		return new js.lib.Promise<String>((resolve, reject) -> {
			var http = new haxe.http.HttpNodeJs('https://api.github.com/repos/$owner/$repo/releases/latest');
			http.addHeader("User-Agent", "ideckia");

			http.onError = (e) -> {
				Log.error('Error checking the releases of [$moduleName].');
				Log.raw(e);
			};
			http.onData = (data) -> {
				var ghRelease = (haxe.Json.parse(data.toString()) : GhRelease);
				var remoteVersion = extractSemVer(ghRelease.tag_name);
				if (remoteVersion > currentVersion) {
					Ideckia.dialog.question('New version available', 'Newer version of [$moduleName] found: Local [$currentVersion] / Remote [$remoteVersion]')
						.then(isOk -> {
							if (!isOk)
								return;

							var downloadUrl = '';
							for (asset in ghRelease.assets) {
								if (asset.name == filename) {
									downloadUrl = asset.browser_download_url;
									break;
								}
							}
							resolve(downloadUrl);
						});
				} else {
					Log.debug('No updates found for [$moduleName]');
				}
			};
			http.request();
		});
	}

	static function downloadRemoteAsset(moduleName:String, downloadUrl:String) {
		return new js.lib.Promise<haxe.io.Bytes>((resolve, reject) -> {
			if (downloadUrl == '')
				return;
			Log.debug('Downloading [$downloadUrl]');
			fetch(downloadUrl).all().handle(o -> switch o {
				case Success(res):
					var statusCode = res.header.statusCode;
					if (statusCode == 200) {
						resolve(res.body.toBytes());
					} else {
						Log.error('Something went wrong downloading [$moduleName]. Status: [$statusCode]');
					}
				case Failure(e):
					Log.error('Error getting the release of [$moduleName]: ' + e.message);
					Log.raw(e);
			});
		});
	}

	static function extractSemVer(version:String) {
		return switch Version.parse(version.replace('v', '')) {
			case Success(ver):
				ver;
			case Failure(_):
				new Version(0, 0, 0);
		};
	}

	static function unzip(bytes:haxe.io.Bytes, dest:String, ignoreRootFolder:String = "") {
		var entries = haxe.zip.Reader.readZip(new haxe.io.BytesInput(bytes));

		for (entry in entries) {
			var fileName = entry.fileName;
			if (fileName.charAt(0) != "/" && fileName.charAt(0) != "\\" && fileName.split("..").length <= 1) {
				var dirs = ~/[\/\\]/g.split(fileName);
				if ((ignoreRootFolder != "" && dirs.length > 1) || ignoreRootFolder == "") {
					if (ignoreRootFolder != "") {
						dirs.shift();
					}

					var path = "";
					var file = dirs.pop();
					for (d in dirs) {
						path += d;
						sys.FileSystem.createDirectory(dest + "/" + path);
						path += "/";
					}

					if (file == "") {
						if (path != "")
							Log.debug("created " + path);
						continue;
					}
					path += file;
					Log.debug("unzip " + path);

					var data = haxe.zip.Reader.unzip(entry);
					var f = sys.io.File.write(dest + "/" + path, true);
					f.write(data);
					f.close();
				}
			}
		}
	}
}
