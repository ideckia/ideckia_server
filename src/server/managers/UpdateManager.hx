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

typedef GHRelease = {
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
		Log.debug('Checking updates for [$moduleName]');
		if (!sys.FileSystem.exists(infoPath))
			return;

		var content = try sys.io.File.getContent(infoPath) catch (e) '';
		var info:Info = haxe.Json.parse(content);

		if (info.repository == null || info.filename == null || info.version == null)
			return;

		var githubEreg = ~/github.com\/([\w-\.]*)\/([\w-\.]*)/;

		if (githubEreg.match(info.repository)) {
			var owner = githubEreg.matched(1);
			var repo = githubEreg.matched(2);
			getGithubRelease(path, moduleName, info, owner, repo);
		}
	}

	static function getGithubRelease(path:String, moduleName:String, info:Info, owner:String, repo:String) {
		var endpoint = 'https://api.github.com/repos/$owner/$repo/releases/latest';

		var http = new haxe.http.HttpNodeJs(endpoint);
		http.addHeader("User-Agent", "ideckia");

		http.onError = (e) -> trace('Error checking the releases: ' + e);
		http.onData = (data) -> {
			var ghRelease = (haxe.Json.parse(data.toString()) : GHRelease);
			var localVersion = extractSemVer(info.version);
			var remoteVersion = extractSemVer(ghRelease.tag_name);
			if (remoteVersion > localVersion) {
				Ideckia.dialog.question('New version available', 'Newer version of [$moduleName] found: Local [$localVersion] / Remote [$remoteVersion]')
					.then(isOk -> {
						if (isOk) {
							var downloadUrl = '';
							for (asset in ghRelease.assets) {
								if (asset.name == info.filename) {
									downloadUrl = asset.browser_download_url;
									break;
								}
							}
							if (downloadUrl != '') {
								Log.debug('Downloading $downloadUrl');
								fetch(downloadUrl).all().handle(o -> switch o {
									case Success(res):
										if (res.header.statusCode == 200) unzip(res.body.toBytes(), path);
									case Failure(e):
										trace('Error getting the release: ' + e);
								});
							}
						}
					});
			}
		};
		http.request();
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
						continue; // was just a directory
					}
					path += file;
					Log.debug("unzip " + path);

					var data = haxe.zip.Reader.unzip(entry);
					var f = sys.io.File.write(dest + "/" + path, true);
					f.write(data);
					f.close();
				}
			}
		} // entry

		Sys.println('');
		Sys.println('unzipped successfully to ${dest}');
	} // unzip
}
