class Macros {
	static public inline var DEV_COMMIT_PREFIX = ' > commit ';

	public static macro function buildDate():haxe.macro.Expr.ExprOf<Date> {
		var now = Date.now();

		return macro new Date($v{now.getFullYear()}, $v{now.getMonth()}, $v{now.getDate()}, $v{now.getHours()}, $v{now.getMinutes()}, $v{now.getSeconds()});
	}

	public static macro function getGitCommitHash():haxe.macro.Expr.ExprOf<String> {
		#if !display
		var process = new sys.io.Process('git', ['rev-parse', 'HEAD']);
		if (process.exitCode() != 0) {
			var message = process.stderr.readAll().toString();
			var pos = haxe.macro.Context.currentPos();
			haxe.macro.Context.error("Cannot execute `git rev-parse HEAD`. " + message, pos);
		}

		// read the output of the process
		var commitHash:String = process.stdout.readLine();
		#else
		// `#if display` is used for code completion. In this case returning an
		// empty string is good enough; We don't want to call git on every hint.
		var commitHash:String = "";
		#end

		// Generates a string expression
		return macro $v{DEV_COMMIT_PREFIX + '$commitHash'};
	}

	public static macro function getLastTagName():haxe.macro.Expr.ExprOf<String> {
		#if !display
		var process = new sys.io.Process('git tag --sort=taggerdate');

		if (process.exitCode() != 0) {
			var message = process.stderr.readAll().toString();
			var pos = haxe.macro.Context.currentPos();
			haxe.macro.Context.error("Cannot execute `git tag --sort=taggerdate`. " + message, pos);
		}

		// read the output of the process
		var lastTagName = process.stdout.readLine();
		while (lastTagName != null) {
			try {
				lastTagName = process.stdout.readLine();
			} catch (e:Any) {
				break;
			}
		}
		#else
		// `#if display` is used for code completion. In this case returning an
		// empty string is good enough; We don't want to call git on every hint.
		var lastTagName:String = "";
		#end

		// Generates a string expression
		return macro $v{lastTagName};
	}
}
